require 'rails_helper'

RSpec.describe Tasks::MergeJob, type: :job do
  let(:user) { create(:user) }
  let(:github_credential) { create(:credential, user: user) }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pr_open, branch_name: 'feature/test-branch') }

  describe '#perform' do
    context 'with successful merge' do
      it 'delegates to MergeFinishedBranch interaction' do
        expect(Tasks::MergeFinishedBranch).to receive(:run).with(task: task).and_return(
          double(valid?: true, result: { task: task, merge_sha: 'abc123' })
        )

        described_class.new.perform(task.id)
      end

      it 'logs success message' do
        allow(Tasks::MergeFinishedBranch).to receive(:run).and_return(
          double(valid?: true, result: { task: task, merge_sha: 'abc123' })
        )
        expect(Rails.logger).to receive(:info).with(/Merge completed successfully/)

        described_class.new.perform(task.id)
      end

      it 'does not raise error on success' do
        allow(Tasks::MergeFinishedBranch).to receive(:run).and_return(
          double(valid?: true, result: { task: task, merge_sha: 'abc123' })
        )

        expect {
          described_class.new.perform(task.id)
        }.not_to raise_error
      end
    end

    context 'when merge fails' do
      let(:error_messages) { ['Failed to merge pull request'] }
      let(:failed_outcome) { double(valid?: false, errors: double(full_messages: error_messages)) }

      before do
        allow(Tasks::MergeFinishedBranch).to receive(:run).and_return(failed_outcome)
      end

      it 'logs error message' do
        expect(Rails.logger).to receive(:error).with(/Merge failed/)

        expect {
          described_class.new.perform(task.id)
        }.to raise_error(StandardError)
      end

      it 'raises StandardError with error messages' do
        expect {
          described_class.new.perform(task.id)
        }.to raise_error(StandardError, /Failed to merge pull request/)
      end
    end

    context 'when task is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'job queueing' do
      it 'queues on default queue' do
        expect(described_class.new.queue_name).to eq('default')
      end

      it 'can be enqueued' do
        expect {
          described_class.perform_later(task.id)
        }.to have_enqueued_job(described_class).with(task.id)
      end

      it 'can be performed immediately' do
        allow(Tasks::MergeFinishedBranch).to receive(:run).and_return(
          double(valid?: true, result: { task: task, merge_sha: 'abc123' })
        )

        expect {
          described_class.perform_now(task.id)
        }.not_to raise_error
      end
    end
  end
end
