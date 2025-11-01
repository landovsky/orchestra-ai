require 'rails_helper'

RSpec.describe Tasks::MergeFinishedBranch, type: :interaction do
  let(:user) { create(:user) }
  let(:github_credential) { create(:credential, user: user) }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pr_open, branch_name: 'feature/test-branch', pr_url: 'https://github.com/user/repo/pull/123') }
  let(:github_service) { instance_double(Services::GithubService) }
  let(:merge_sha) { 'abc123def456' }

  before do
    allow(Services::GithubService).to receive(:new).with(github_credential).and_return(github_service)
  end

  describe '#execute' do
    context 'with successful merge' do
      before do
        allow(github_service).to receive(:merge_pull_request).with(task).and_return(merge_sha)
        allow(github_service).to receive(:delete_branch).with(task).and_return(true)
      end

      it 'merges the pull request' do
        expect(github_service).to receive(:merge_pull_request).with(task)

        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
      end

      it 'deletes the feature branch' do
        expect(github_service).to receive(:delete_branch).with(task)

        described_class.run(task: task)
      end

      it 'updates task status to merging' do
        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('merging')
      end

      it 'adds log message with merge SHA' do
        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('PR merged successfully')
        expect(task.reload.debug_log).to include(merge_sha)
      end

      it 'returns updated task and merge SHA' do
        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
        expect(outcome.result[:task]).to eq(task)
        expect(outcome.result[:merge_sha]).to eq(merge_sha)
      end

      it 'logs info messages' do
        expect(Rails.logger).to receive(:info).with(/Starting merge process/)
        expect(Rails.logger).to receive(:info).with(/Successfully merged PR/)
        expect(Rails.logger).to receive(:info).with(/Successfully deleted branch/)
        expect(Rails.logger).to receive(:info).with(/Merge process completed/)

        described_class.run(task: task)
      end
    end

    context 'when merge fails' do
      let(:error_message) { 'Pull request is not mergeable' }

      before do
        allow(github_service).to receive(:merge_pull_request).with(task).and_raise(StandardError, error_message)
      end

      it 'returns invalid outcome with error' do
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:base]).to include("Failed to merge pull request: #{error_message}")
      end

      it 'does not update task status' do
        described_class.run(task: task)

        expect(task.reload.status).to eq('pr_open')
      end

      it 'does not attempt to delete branch' do
        expect(github_service).not_to receive(:delete_branch)

        described_class.run(task: task)
      end

      it 'logs error message' do
        expect(Rails.logger).to receive(:error).with(/Failed to merge PR/)

        described_class.run(task: task)
      end
    end

    context 'when branch deletion fails' do
      before do
        allow(github_service).to receive(:merge_pull_request).with(task).and_return(merge_sha)
        allow(github_service).to receive(:delete_branch).with(task).and_raise(StandardError, 'Branch not found')
      end

      it 'still succeeds (merge was successful)' do
        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
      end

      it 'updates task status to merging' do
        outcome = described_class.run(task: task)

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('merging')
      end

      it 'logs warning about branch deletion failure' do
        expect(Rails.logger).to receive(:warn).with(/Failed to delete branch/)

        described_class.run(task: task)
      end
    end

    context 'when status update fails' do
      before do
        allow(github_service).to receive(:merge_pull_request).with(task).and_return(merge_sha)
        allow(github_service).to receive(:delete_branch).with(task).and_return(true)
        allow(Tasks::UpdateStatus).to receive(:run).and_return(
          double(valid?: false, errors: double(full_messages: ['Status update failed']))
        )
      end

      it 'returns invalid outcome with error' do
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:base]).to include('Failed to update task status: Status update failed')
      end

      it 'logs error message' do
        expect(Rails.logger).to receive(:error).with(/Failed to update status/)

        described_class.run(task: task)
      end
    end

    context 'validation errors' do
      it 'fails when task is nil' do
        outcome = described_class.run(task: nil)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('cannot be blank')
      end

      it 'fails when task has no branch name' do
        task.update_column(:branch_name, nil)
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('must have a branch name')
      end

      it 'fails when task has no epic' do
        task.update_column(:epic_id, nil)
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('must belong to an epic')
      end

      it 'fails when epic has no repository' do
        epic.update_column(:repository_id, nil)
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('must have a repository')
      end

      it 'fails when repository has no GitHub credentials' do
        repository.update_column(:github_credential_id, nil)
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('repository must have GitHub credentials')
      end

      it 'fails when task is not in pr_open status' do
        task.update_column(:status, Task.statuses[:pending])
        outcome = described_class.run(task: task)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:task]).to include('must be in pr_open status to merge')
      end

      %w[pending running merging completed failed].each do |status|
        it "fails when task status is #{status}" do
          task.update_column(:status, Task.statuses[status])
          outcome = described_class.run(task: task)

          expect(outcome).not_to be_valid
          expect(outcome.errors[:task]).to include(/must be in pr_open status/)
        end
      end
    end

    context 'integration with GithubService' do
      it 'initializes GithubService with repository credentials' do
        expect(Services::GithubService).to receive(:new).with(github_credential).and_return(github_service)
        allow(github_service).to receive(:merge_pull_request).and_return(merge_sha)
        allow(github_service).to receive(:delete_branch).and_return(true)

        described_class.run(task: task)
      end
    end
  end
end
