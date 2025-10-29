# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::CursorAgentService do
  describe '#initialize' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'cursor_agent') }

    context 'with a valid credential' do
      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service).to be_a(Services::CursorAgentService)
        expect(service.credential).to eq(credential)
        expect(service.api_key).to eq(credential.api_key)
      end

      it 'stores the API key from the credential' do
        service = described_class.new(credential)
        
        expect(service.api_key).to eq(credential.api_key)
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

  describe '#launch_agent' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'cursor_agent') }
    let(:github_credential) { create(:credential, user: user, service_name: 'github') }
    let(:repository) do
      create(:repository, 
             user: user, 
             github_credential: github_credential, 
             name: 'owner/repo',
             github_url: 'https://github.com/owner/repo')
    end
    let(:epic) { create(:epic, user: user, repository: repository, base_branch: 'main') }
    let(:task) do
      create(:task, 
             epic: epic, 
             description: 'Implement user authentication', 
             position: 0)
    end
    let(:service) { described_class.new(credential) }
    let(:webhook_url) { 'https://app.example.com/webhooks/cursor/123' }
    let(:branch_name) { 'cursor-agent/task-1-abc123' }

    context 'with valid parameters and successful API response' do
      let(:mock_response) do
        instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_abc123","status":"pending"}',
          code: '200'
        )
      end

      before do
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)
      end

      it 'successfully launches an agent and returns parsed response' do
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_abc123', 'status' => 'pending' })
      end

      it 'builds the correct payload structure' do
        expected_payload = {
          prompt: {
            text: 'Implement user authentication'
          },
          source: {
            repository: 'https://github.com/owner/repo',
            ref: 'main'
          },
          target: {
            branchName: 'cursor-agent/task-1-abc123',
            autoCreatePr: true
          },
          webhook: {
            url: webhook_url,
            secret: Services::CursorAgentService::WEBHOOK_SECRET
          }
        }

        expect(service).to receive(:post_to_cursor_api).with(expected_payload).and_return(mock_response)
        
        service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
      end
    end

    context 'with invalid task parameters' do
      it 'raises ArgumentError when task is nil' do
        expect {
          service.launch_agent(task: nil, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Task cannot be nil')
      end

      it 'raises ArgumentError when task has no description' do
        task.description = nil
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Task must have a description')
      end

      it 'raises ArgumentError when task has blank description' do
        task.description = ''
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Task must have a description')
      end

      it 'raises ArgumentError when task has no epic' do
        task_without_epic = build(:task, epic: nil, position: 0)
        
        expect {
          service.launch_agent(task: task_without_epic, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Task must belong to an epic')
      end

      it 'raises ArgumentError when epic has no repository' do
        epic_without_repo = build(:epic, user: user, repository: nil)
        task_with_invalid_epic = build(:task, epic: epic_without_repo, position: 0)
        
        expect {
          service.launch_agent(task: task_with_invalid_epic, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Epic must have a repository')
      end

      it 'raises ArgumentError when repository has no github_url' do
        repository.github_url = nil
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Repository must have a github_url')
      end

      it 'raises ArgumentError when repository has blank github_url' do
        repository.github_url = ''
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Repository must have a github_url')
      end

      it 'raises ArgumentError when epic has no base_branch' do
        epic.base_branch = nil
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Epic must have a base_branch')
      end

      it 'raises ArgumentError when epic has blank base_branch' do
        epic.base_branch = ''
        
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'Epic must have a base_branch')
      end
    end

    context 'with invalid webhook_url parameter' do
      it 'raises ArgumentError when webhook_url is nil' do
        expect {
          service.launch_agent(task: task, webhook_url: nil, branch_name: branch_name)
        }.to raise_error(ArgumentError, 'webhook_url cannot be blank')
      end

      it 'raises ArgumentError when webhook_url is blank' do
        expect {
          service.launch_agent(task: task, webhook_url: '', branch_name: branch_name)
        }.to raise_error(ArgumentError, 'webhook_url cannot be blank')
      end

      it 'raises ArgumentError when webhook_url is whitespace only' do
        expect {
          service.launch_agent(task: task, webhook_url: '   ', branch_name: branch_name)
        }.to raise_error(ArgumentError, 'webhook_url cannot be blank')
      end
    end

    context 'with invalid branch_name parameter' do
      it 'raises ArgumentError when branch_name is nil' do
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: nil)
        }.to raise_error(ArgumentError, 'branch_name cannot be blank')
      end

      it 'raises ArgumentError when branch_name is blank' do
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: '')
        }.to raise_error(ArgumentError, 'branch_name cannot be blank')
      end

      it 'raises ArgumentError when branch_name is whitespace only' do
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: '   ')
        }.to raise_error(ArgumentError, 'branch_name cannot be blank')
      end
    end

    context 'when API returns an error response' do
      it 'raises StandardError for 400 Bad Request' do
        mock_error_response = instance_double(
          Net::HTTPBadRequest,
          body: '{"error":"Invalid request"}',
          code: '400'
        )
        allow(mock_error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(service).to receive(:post_to_cursor_api).and_return(mock_error_response)

        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(StandardError, /Cursor API request failed/)
      end

      it 'raises StandardError for 401 Unauthorized' do
        mock_error_response = instance_double(
          Net::HTTPUnauthorized,
          body: '{"error":"Invalid API key"}',
          code: '401'
        )
        allow(mock_error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(service).to receive(:post_to_cursor_api).and_return(mock_error_response)

        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(StandardError, /Cursor API request failed/)
      end

      it 'raises StandardError for 500 Internal Server Error' do
        mock_error_response = instance_double(
          Net::HTTPInternalServerError,
          body: '{"error":"Server error"}',
          code: '500'
        )
        allow(mock_error_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(service).to receive(:post_to_cursor_api).and_return(mock_error_response)

        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(StandardError, /Cursor API request failed/)
      end
    end

    context 'when JSON parsing fails' do
      let(:mock_response) do
        instance_double(
          Net::HTTPSuccess,
          body: 'Invalid JSON {{{',
          code: '200'
        )
      end

      before do
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(StandardError, /Failed to parse Cursor API response/)
      end
    end

    context 'when network error occurs' do
      before do
        allow(service).to receive(:post_to_cursor_api)
          .and_raise(StandardError.new('Failed to communicate with Cursor API: Connection timeout'))
      end

      it 'raises StandardError with appropriate message' do
        expect {
          service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        }.to raise_error(StandardError, /Failed to communicate with Cursor API/)
      end
    end

    context 'with complex task descriptions' do
      let(:mock_response) do
        instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_xyz789","status":"pending"}',
          code: '200'
        )
      end

      before do
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)
      end

      it 'handles task descriptions with special characters' do
        task.description = 'Add user auth with OAuth2 & JWT tokens (secure)'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_xyz789', 'status' => 'pending' })
      end

      it 'handles multi-line task descriptions' do
        task.description = "Implement user authentication\n- Add login endpoint\n- Add logout endpoint"
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_xyz789', 'status' => 'pending' })
      end

      it 'handles task descriptions with quotes' do
        task.description = 'Add "admin" role to user model'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_xyz789', 'status' => 'pending' })
      end
    end

    context 'with different repository URLs' do
      let(:mock_response) do
        instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_test123","status":"pending"}',
          code: '200'
        )
      end

      before do
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)
      end

      it 'handles HTTPS GitHub URLs' do
        repository.github_url = 'https://github.com/myorg/myrepo'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_test123', 'status' => 'pending' })
      end

      it 'handles SSH GitHub URLs' do
        repository.github_url = 'git@github.com:myorg/myrepo.git'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_test123', 'status' => 'pending' })
      end

      it 'handles GitHub URLs with .git suffix' do
        repository.github_url = 'https://github.com/myorg/myrepo.git'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_test123', 'status' => 'pending' })
      end
    end

    context 'with different base branches' do
      let(:mock_response) do
        instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_branch123","status":"pending"}',
          code: '200'
        )
      end

      before do
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)
      end

      it 'handles main branch' do
        epic.base_branch = 'main'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_branch123', 'status' => 'pending' })
      end

      it 'handles master branch' do
        epic.base_branch = 'master'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_branch123', 'status' => 'pending' })
      end

      it 'handles custom branches with slashes' do
        epic.base_branch = 'feature/epic-123'
        
        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_branch123', 'status' => 'pending' })
      end
    end

    context 'API response variations' do
      it 'correctly parses response with additional fields' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_full123","status":"pending","created_at":"2025-10-29T00:00:00Z","metadata":{"key":"value"}}',
          code: '200'
        )
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)

        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result['id']).to eq('bc_full123')
        expect(result['status']).to eq('pending')
        expect(result['metadata']).to eq({ 'key' => 'value' })
      end

      it 'correctly parses minimal response' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"id":"bc_min123"}',
          code: '200'
        )
        allow(service).to receive(:post_to_cursor_api).and_return(mock_response)

        result = service.launch_agent(task: task, webhook_url: webhook_url, branch_name: branch_name)
        
        expect(result).to eq({ 'id' => 'bc_min123' })
      end
    end
  end

  describe 'constants' do
    it 'defines the correct API endpoint' do
      expect(Services::CursorAgentService::CURSOR_API_ENDPOINT).to eq('https://api.cursor.com/v0/agents')
    end

    it 'defines a webhook secret constant' do
      expect(Services::CursorAgentService::WEBHOOK_SECRET).to be_a(String)
      expect(Services::CursorAgentService::WEBHOOK_SECRET).not_to be_empty
    end
  end
end
