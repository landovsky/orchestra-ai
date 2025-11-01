require 'rails_helper'

RSpec.describe Webhooks::ProcessCursorStatus, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pending) }

  describe '#execute' do
    context 'with FINISHED status' do
      let(:payload) { { 'status' => 'FINISHED', 'target' => { 'prUrl' => 'https://github.com/user/repo/pull/123' } } }

      it 'delegates to HandleFinishedStatus' do
        expect(Webhooks::HandleFinishedStatus).to receive(:run).with(
          task: task,
          payload: payload
        ).and_call_original

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('FINISHED')
      end

      it 'returns task and status on success' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:status]).to eq('FINISHED')
      end

      it 'handles handler interaction failure' do
        allow(Webhooks::HandleFinishedStatus).to receive(:run).and_return(
          double(valid?: false, errors: double(full_messages: ['Handler error']))
        )

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:base]).to include('Failed to handle finished status: Handler error')
      end
    end

    context 'with RUNNING status' do
      let(:payload) { { 'status' => 'RUNNING' } }

      it 'delegates to HandleRunningStatus' do
        expect(Webhooks::HandleRunningStatus).to receive(:run).with(
          task: task,
          payload: payload
        ).and_call_original

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('RUNNING')
      end
    end

    context 'with ERROR status' do
      let(:payload) { { 'status' => 'ERROR', 'error_message' => 'Something went wrong' } }

      it 'delegates to HandleErrorStatus' do
        expect(Webhooks::HandleErrorStatus).to receive(:run).with(
          task: task,
          payload: payload
        ).and_call_original

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('ERROR')
      end
    end

    context 'with unknown status' do
      let(:payload) { { 'status' => 'UNKNOWN_STATUS' } }

      it 'logs warning but succeeds' do
        expect(Rails.logger).to receive(:warn).with(/Unknown status UNKNOWN_STATUS/)

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('UNKNOWN_STATUS')
      end
    end

    context 'status extraction from different payload formats' do
      it 'extracts from direct status parameter (string key)' do
        payload = { 'status' => 'FINISHED' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('FINISHED')
      end

      it 'extracts from direct status parameter (symbol key)' do
        payload = { status: 'RUNNING' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('RUNNING')
      end

      it 'extracts from nested data structure (string keys)' do
        payload = { 'data' => { 'status' => 'ERROR' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('ERROR')
      end

      it 'extracts from nested data structure (symbol keys)' do
        payload = { data: { status: 'FINISHED' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('FINISHED')
      end

      it 'extracts from event parameter' do
        payload = { 'event' => 'RUNNING' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('RUNNING')
      end
    end

    context 'with missing status' do
      let(:payload) { { 'other_field' => 'value' } }

      it 'fails with error' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:base]).to include('Invalid webhook payload - missing status')
      end
    end

    context 'with invalid inputs' do
      it 'requires task' do
        outcome = described_class.run(task: nil, payload: { 'status' => 'RUNNING' })

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to be_present
      end

      it 'requires payload' do
        expect {
          described_class.run(task: task, payload: nil)
        }.to raise_error(ActiveInteraction::InvalidInteractionError)
      end
    end

    context 'case insensitivity' do
      it 'handles lowercase status' do
        payload = { 'status' => 'finished' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:status]).to eq('finished')
      end

      it 'handles mixed case status' do
        payload = { 'status' => 'FiNiShEd' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
      end
    end
  end
end
