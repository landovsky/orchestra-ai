require 'rails_helper'

RSpec.describe Webhooks::HandleErrorStatus, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pending) }

  describe '#execute' do
    context 'with error message in payload' do
      let(:error_message) { 'Connection timeout' }
      let(:payload) { { 'error_message' => error_message } }

      it 'transitions task to failed status' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('failed')
      end

      it 'adds log message with error' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('Cursor agent failed')
        expect(task.reload.debug_log).to include(error_message)
      end

      it 'returns updated task and error message' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:error_message]).to eq(error_message)
      end

      it 'logs info messages' do
        expect(Rails.logger).to receive(:info).with(/Handling ERROR status/)
        expect(Rails.logger).to receive(:info).with(/Successfully transitioned to failed/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'without error message in payload' do
      let(:payload) { {} }

      it 'transitions to failed with default message' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('failed')
      end

      it 'adds log message with "Unknown error"' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('Unknown error')
      end

      it 'returns task with nil error message' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to be_nil
      end
    end

    context 'error message extraction from different formats' do
      it 'extracts from error_message field (string key)' do
        payload = { 'error_message' => 'Test error 1' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 1')
      end

      it 'extracts from error_message field (symbol key)' do
        payload = { error_message: 'Test error 2' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 2')
      end

      it 'extracts from error field (string key)' do
        payload = { 'error' => 'Test error 3' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 3')
      end

      it 'extracts from error field (symbol key)' do
        payload = { error: 'Test error 4' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 4')
      end

      it 'extracts from data.error' do
        payload = { 'data' => { 'error' => 'Test error 5' } }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 5')
      end

      it 'extracts from message field' do
        payload = { 'message' => 'Test error 6' }
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:error_message]).to eq('Test error 6')
      end
    end

    context 'when status update fails' do
      let(:payload) { { 'error_message' => 'Test error' } }

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
