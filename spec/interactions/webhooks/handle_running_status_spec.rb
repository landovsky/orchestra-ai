require 'rails_helper'

RSpec.describe Webhooks::HandleRunningStatus, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pending) }
  let(:payload) { {} }

  describe '#execute' do
    context 'when task is pending' do
      it 'transitions task to running status' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('running')
      end

      it 'adds log message' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('Cursor agent is now running')
      end

      it 'returns updated task' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:skipped]).to be_nil
      end

      it 'logs info messages' do
        expect(Rails.logger).to receive(:info).with(/Handling RUNNING status/)
        expect(Rails.logger).to receive(:info).with(/Successfully transitioned to running/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'when task is already running' do
      before { task.update!(status: :running) }

      it 'does not update status' do
        expect(Tasks::UpdateStatus).not_to receive(:run)

        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('running')
      end

      it 'returns task with skipped flag' do
        outcome = described_class.run(task: task, payload: payload)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:skipped]).to be true
      end

      it 'logs info about skipping' do
        expect(Rails.logger).to receive(:info).with(/Handling RUNNING status/)
        expect(Rails.logger).to receive(:info).with(/Already in running status/)

        described_class.run(task: task, payload: payload)
      end
    end

    context 'when task is beyond running status' do
      %w[pr_open merging completed failed].each do |status|
        context "when status is #{status}" do
          before { task.update!(status: status) }

          it 'does not update status' do
            expect(Tasks::UpdateStatus).not_to receive(:run)

            outcome = described_class.run(task: task, payload: payload)

            expect(outcome).to be_valid
            expect(task.reload.status).to eq(status)
          end

          it 'returns task with skipped flag' do
            outcome = described_class.run(task: task, payload: payload)

            expect(outcome).to be_valid
            expect(outcome.result[:skipped]).to be true
          end

          it 'logs info about current status' do
            expect(Rails.logger).to receive(:info).with(/Already in #{status} status/)

            described_class.run(task: task, payload: payload)
          end
        end
      end
    end

    context 'when status update fails' do
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
        outcome = described_class.run(task: nil, payload: payload)

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
