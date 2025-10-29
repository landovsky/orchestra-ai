# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::GithubService do
  describe '#initialize' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }

    context 'with a valid credential' do
      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service).to be_a(Services::GithubService)
        expect(service.credential).to eq(credential)
        expect(service.client).to be_a(Octokit::Client)
      end

      it 'configures the Octokit client with the correct access token' do
        service = described_class.new(credential)
        
        expect(service.client.access_token).to eq(credential.api_key)
      end

      it 'enables auto_paginate on the Octokit client' do
        service = described_class.new(credential)
        
        expect(service.client.auto_paginate).to be true
      end
    end

    context 'with an invalid credential' do
      it 'raises ArgumentError when credential is nil' do
        expect {
          described_class.new(nil)
        }.to raise_error(ArgumentError, 'Credential cannot be nil')
      end

      it 'raises ArgumentError when credential has no api_key' do
        credential_without_key = build(:credential, user: user, api_key: nil)
        
        expect {
          described_class.new(credential_without_key)
        }.to raise_error(ArgumentError, 'Credential must have an api_key')
      end

      it 'raises ArgumentError when credential has blank api_key' do
        credential_with_blank_key = build(:credential, user: user, api_key: '')
        
        expect {
          described_class.new(credential_with_blank_key)
        }.to raise_error(ArgumentError, 'Credential must have an api_key')
      end
    end
  end

  describe '#merge_pull_request' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }
    let(:repository) { create(:repository, user: user, github_credential: credential, name: 'owner/repo') }
    let(:epic) { create(:epic, user: user, repository: repository) }
    let(:task) { create(:task, epic: epic, branch_name: 'feature-branch', position: 0) }
    let(:service) { described_class.new(credential) }
    let(:mock_client) { instance_double(Octokit::Client) }

    before do
      allow(service).to receive(:client).and_return(mock_client)
    end

    context 'with a valid task and mergeable PR' do
      let(:mock_pr) do
        double(
          'Pull Request',
          number: 123,
          head: double(ref: 'feature-branch'),
          mergeable: true
        )
      end
      let(:mock_merge_result) { double('Merge Result', sha: 'abc123def456') }

      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([mock_pr])
        allow(mock_client).to receive(:merge_pull_request)
          .with('owner/repo', 123, 'Merge pull request #123 from feature-branch')
          .and_return(mock_merge_result)
      end

      it 'successfully merges the pull request and returns the merge SHA' do
        result = service.merge_pull_request(task)
        
        expect(result).to eq('abc123def456')
      end

      it 'calls the Octokit client with correct parameters' do
        service.merge_pull_request(task)
        
        expect(mock_client).to have_received(:pull_requests).with('owner/repo', state: 'open')
        expect(mock_client).to have_received(:merge_pull_request)
          .with('owner/repo', 123, 'Merge pull request #123 from feature-branch')
      end
    end

    context 'when PR is not found by branch name' do
      let(:other_pr) do
        double(
          'Other Pull Request',
          number: 456,
          head: double(ref: 'different-branch'),
          mergeable: true
        )
      end

      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([other_pr])
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, "Pull request not found for branch 'feature-branch'")
      end
    end

    context 'when PR is not mergeable' do
      let(:mock_pr) do
        double(
          'Pull Request',
          number: 123,
          head: double(ref: 'feature-branch'),
          mergeable: false
        )
      end

      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([mock_pr])
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, 'Pull request #123 is not mergeable')
      end
    end

    context 'when Octokit raises NotFound' do
      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_raise(Octokit::NotFound.new)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, /Pull request not found/)
      end
    end

    context 'when Octokit raises MethodNotAllowed' do
      let(:mock_pr) do
        double(
          'Pull Request',
          number: 123,
          head: double(ref: 'feature-branch'),
          mergeable: true
        )
      end

      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([mock_pr])
        allow(mock_client).to receive(:merge_pull_request)
          .and_raise(Octokit::MethodNotAllowed.new)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, /Pull request cannot be merged/)
      end
    end

    context 'when Octokit raises Conflict' do
      let(:mock_pr) do
        double(
          'Pull Request',
          number: 123,
          head: double(ref: 'feature-branch'),
          mergeable: true
        )
      end

      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([mock_pr])
        allow(mock_client).to receive(:merge_pull_request)
          .and_raise(Octokit::Conflict.new)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, /Pull request has conflicts/)
      end
    end

    context 'with invalid task parameters' do
      it 'raises ArgumentError when task is nil' do
        expect {
          service.merge_pull_request(nil)
        }.to raise_error(ArgumentError, 'Task cannot be nil')
      end

      it 'raises ArgumentError when task has no branch_name' do
        task.branch_name = nil
        
        expect {
          service.merge_pull_request(task)
        }.to raise_error(ArgumentError, 'Task must have a branch_name')
      end

      it 'raises ArgumentError when task has blank branch_name' do
        task.branch_name = ''
        
        expect {
          service.merge_pull_request(task)
        }.to raise_error(ArgumentError, 'Task must have a branch_name')
      end

      it 'raises ArgumentError when task has no epic' do
        task_without_epic = build(:task, epic: nil, position: 0)
        
        expect {
          service.merge_pull_request(task_without_epic)
        }.to raise_error(ArgumentError, 'Task must belong to an epic')
      end

      it 'raises ArgumentError when epic has no repository' do
        epic_without_repo = build(:epic, user: user, repository: nil)
        task_with_invalid_epic = build(:task, epic: epic_without_repo, position: 0)
        
        expect {
          service.merge_pull_request(task_with_invalid_epic)
        }.to raise_error(ArgumentError, 'Epic must have a repository')
      end

      it 'raises ArgumentError when repository has blank name' do
        repository.name = ''
        
        expect {
          service.merge_pull_request(task)
        }.to raise_error(ArgumentError, 'Repository must have a name')
      end
    end

    context 'when no open PRs exist' do
      before do
        allow(mock_client).to receive(:pull_requests)
          .with('owner/repo', state: 'open')
          .and_return([])
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.merge_pull_request(task)
        }.to raise_error(StandardError, "Pull request not found for branch 'feature-branch'")
      end
    end
  end

  describe '#delete_branch' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }
    let(:repository) { create(:repository, user: user, github_credential: credential, name: 'owner/repo') }
    let(:epic) { create(:epic, user: user, repository: repository) }
    let(:task) { create(:task, epic: epic, branch_name: 'feature-branch', position: 0) }
    let(:service) { described_class.new(credential) }
    let(:mock_client) { instance_double(Octokit::Client) }

    before do
      allow(service).to receive(:client).and_return(mock_client)
    end

    context 'with a valid task and existing branch' do
      before do
        allow(mock_client).to receive(:delete_ref)
          .with('owner/repo', 'heads/feature-branch')
          .and_return(true)
      end

      it 'successfully deletes the branch and returns true' do
        result = service.delete_branch(task)
        
        expect(result).to be true
      end

      it 'calls the Octokit client with correct parameters' do
        service.delete_branch(task)
        
        expect(mock_client).to have_received(:delete_ref)
          .with('owner/repo', 'heads/feature-branch')
      end

      it 'uses the correct ref format (heads/branch_name)' do
        service.delete_branch(task)
        
        expect(mock_client).to have_received(:delete_ref)
          .with('owner/repo', 'heads/feature-branch')
      end
    end

    context 'when branch is not found' do
      before do
        allow(mock_client).to receive(:delete_ref)
          .with('owner/repo', 'heads/feature-branch')
          .and_raise(Octokit::NotFound.new)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.delete_branch(task)
        }.to raise_error(StandardError, /Branch 'feature-branch' not found/)
      end
    end

    context 'when branch cannot be deleted' do
      before do
        allow(mock_client).to receive(:delete_ref)
          .with('owner/repo', 'heads/feature-branch')
          .and_raise(Octokit::UnprocessableEntity.new)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.delete_branch(task)
        }.to raise_error(StandardError, /Cannot delete branch 'feature-branch'/)
      end
    end

    context 'with invalid task parameters' do
      it 'raises ArgumentError when task is nil' do
        expect {
          service.delete_branch(nil)
        }.to raise_error(ArgumentError, 'Task cannot be nil')
      end

      it 'raises ArgumentError when task has no branch_name' do
        task.branch_name = nil
        
        expect {
          service.delete_branch(task)
        }.to raise_error(ArgumentError, 'Task must have a branch_name')
      end

      it 'raises ArgumentError when task has blank branch_name' do
        task.branch_name = ''
        
        expect {
          service.delete_branch(task)
        }.to raise_error(ArgumentError, 'Task must have a branch_name')
      end

      it 'raises ArgumentError when task has no epic' do
        task_without_epic = build(:task, epic: nil, position: 0)
        
        expect {
          service.delete_branch(task_without_epic)
        }.to raise_error(ArgumentError, 'Task must belong to an epic')
      end

      it 'raises ArgumentError when epic has no repository' do
        epic_without_repo = build(:epic, user: user, repository: nil)
        task_with_invalid_epic = build(:task, epic: epic_without_repo, position: 0)
        
        expect {
          service.delete_branch(task_with_invalid_epic)
        }.to raise_error(ArgumentError, 'Epic must have a repository')
      end

      it 'raises ArgumentError when repository has blank name' do
        repository.name = ''
        
        expect {
          service.delete_branch(task)
        }.to raise_error(ArgumentError, 'Repository must have a name')
      end
    end

    context 'with branch names containing special characters' do
      before do
        task.branch_name = 'feature/add-new-thing'
        allow(mock_client).to receive(:delete_ref)
          .with('owner/repo', 'heads/feature/add-new-thing')
          .and_return(true)
      end

      it 'correctly handles branch names with slashes' do
        result = service.delete_branch(task)
        
        expect(result).to be true
        expect(mock_client).to have_received(:delete_ref)
          .with('owner/repo', 'heads/feature/add-new-thing')
      end
    end
  end
end
