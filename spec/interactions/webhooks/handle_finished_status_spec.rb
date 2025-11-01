require 'rails_helper'

RSpec.describe Webhooks::HandleFinishedStatus, type: :interaction do
  include ActiveJob::TestHelper
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pending) }

  describe '#execute' do
    context 'with PR URL in payload' do
      let(:pr_url) { 'https://github.com/user/repo/pull/123' }
      let(:payload) { { 'target' => { 'prUrl' => pr_url } } }

      it 'transitions task to pr_open status' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('pr_open')
      end

      it 'saves PR URL to task' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.pr_url).to eq(pr_url)
      end

      it 'adds log message with PR URL' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('Cursor agent finished')
        expect(task.reload.debug_log).to include(pr_url)
      end

      it 'returns updated task and PR URL' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:pr_url]).to eq(pr_url)
      end

      it 'enqueues merge job' do
        expect {
          described_class.run(task: task, payload: payload)
        }.to have_enqueued_job(Tasks::MergeJob).with(task.id)
      end

      it 'logs info messages' do
        expect(Rails.logger).to receive(:info).with(/Handling FINISHED status/)
        expect(Rails.logger).to receive(:info).with(/Successfully transitioned to pr_open/)
        expect(Rails.logger).to receive(:info).with(/Merge job enqueued/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'without PR URL in payload' do
      let(:payload) { {} }

      it 'transitions to pr_open without PR URL' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('pr_open')
        expect(task.pr_url).to be_nil
      end

      it 'adds log message indicating no PR URL' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('URL not provided')
      end

      it 'logs warning about missing PR URL' do
        expect(Rails.logger).to receive(:warn).with(/No PR URL found/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'PR URL extraction from different formats' do
      it 'extracts from target.prUrl (string keys)' do
        payload = { 'target' => { 'prUrl' => 'https://github.com/pr/1' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/1')
      end

      it 'extracts from target.prUrl (symbol keys)' do
        payload = { target: { prUrl: 'https://github.com/pr/2' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/2')
      end

      it 'extracts from target.pr_url (string keys)' do
        payload = { 'target' => { 'pr_url' => 'https://github.com/pr/3' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/3')
      end

      it 'extracts from target.pr_url (symbol keys)' do
        payload = { target: { pr_url: 'https://github.com/pr/4' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/4')
      end

      it 'extracts from direct pr_url parameter' do
        payload = { 'pr_url' => 'https://github.com/pr/5' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/5')
      end

      it 'extracts from direct prUrl parameter' do
        payload = { 'prUrl' => 'https://github.com/pr/6' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/6')
      end

      it 'extracts from data.pr_url' do
        payload = { 'data' => { 'pr_url' => 'https://github.com/pr/7' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/7')
      end

      it 'extracts from data.prUrl' do
        payload = { 'data' => { 'prUrl' => 'https://github.com/pr/8' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:pr_url]).to eq('https://github.com/pr/8')
      end
    end

    context 'when status update fails' do
      let(:payload) { { 'target' => { 'prUrl' => 'https://github.com/pr/1' } } }

      it 'returns invalid outcome with error' do
        allow(Tasks::UpdateStatus).to receive(:run).and_return(
          double(valid?: false, errors: double(full_messages: ['Update failed']))
        )

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:base]).to include('Update failed')
      end

      it 'logs error message' do
        allow(Tasks::UpdateStatus).to receive(:run).and_return(
          double(valid?: false, errors: double(full_messages: ['Update failed']))
        )

        expect(Rails.logger).to receive(:error).with(/Failed to update status/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'with invalid inputs' do
      it 'requires task' do
        outcome = described_class.run(task: nil, payload: {})

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to be_present
      end

      it 'requires payload' do
        expect {
          described_class.run(task: task, payload: nil)
        }.to raise_error(ActiveInteraction::InvalidInteractionError)
      end
    end
  end
end
