# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::ExecuteJob, type: :job do
  let(:user) { create(:user) }
  let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent', api_key: 'test-cursor-key') }
  let(:github_credential) { create(:credential, user: user, service_name: 'github', api_key: 'test-github-key') }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }
  let(:epic) { create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential, base_branch: 'main') }
  let(:task) { create(:task, epic: epic, status: 'pending') }

  let(:mock_cursor_service) { instance_double(Services::CursorAgentService) }
  let(:mock_agent_response) { { 'id' => 'agent-abc123' } }

  before do
    # Set APP_URL for webhook generation
    allow(ENV).to receive(:fetch).with('APP_URL', anything).and_return('http://localhost:3000')
    
    # Mock the CursorAgentService
    allow(Services::CursorAgentService).to receive(:new).with(cursor_credential).and_return(mock_cursor_service)
    allow(mock_cursor_service).to receive(:launch_agent).and_return(mock_agent_response)
  end

  describe '#perform' do
    it 'updates task status to running' do
      described_class.new.perform(task.id)
      
      expect(task.reload.status).to eq('running')
    end

    it 'generates a branch name in the correct format' do
      described_class.new.perform(task.id)
      
      task.reload
      expect(task.branch_name).to match(/^cursor-agent\/task-#{task.id}-[a-f0-9]{8}$/)
    end

    it 'saves the agent ID from Cursor API response' do
      described_class.new.perform(task.id)
      
      expect(task.reload.cursor_agent_id).to eq('agent-abc123')
    end

    it 'calls CursorAgentService.launch_agent with correct parameters' do
      described_class.new.perform(task.id)
      
      expect(mock_cursor_service).to have_received(:launch_agent).with(
        hash_including(
          task: task,
          webhook_url: "http://localhost:3000/webhooks/cursor/#{task.id}"
        )
      )
    end

    it 'logs the execution steps in debug_log' do
      described_class.new.perform(task.id)
      
      task.reload
      expect(task.debug_log).to include('Starting task execution...')
      expect(task.debug_log).to include('Launching Cursor agent for branch:')
      expect(task.debug_log).to include('Cursor agent launched successfully')
      expect(task.debug_log).to include('Agent ID: agent-abc123')
    end

    context 'when cursor credential is missing' do
      before do
        epic.update!(cursor_agent_credential: nil)
      end

      it 'raises an error and marks task as failed' do
        expect {
          described_class.new.perform(task.id)
        }.to raise_error(StandardError, /No Cursor agent credential configured/)
        
        task.reload
        expect(task.status).to eq('failed')
        expect(task.debug_log).to include('Failed to launch Cursor agent')
      end
    end

    context 'when Cursor API returns no agent ID' do
      before do
        allow(mock_cursor_service).to receive(:launch_agent).and_return({})
      end

      it 'raises an error and marks task as failed' do
        expect {
          described_class.new.perform(task.id)
        }.to raise_error(StandardError, /No agent ID returned from Cursor API/)
        
        task.reload
        expect(task.status).to eq('failed')
        expect(task.debug_log).to include('Failed to launch Cursor agent')
      end
    end

    context 'when CursorAgentService raises an error' do
      before do
        allow(mock_cursor_service).to receive(:launch_agent).and_raise(StandardError, 'API connection failed')
      end

      it 'marks task as failed with error message' do
        expect {
          described_class.new.perform(task.id)
        }.to raise_error(StandardError, /API connection failed/)
        
        task.reload
        expect(task.status).to eq('failed')
        expect(task.debug_log).to include('Failed to launch Cursor agent: API connection failed')
      end
    end
  end

  describe '#generate_branch_name (private)' do
    it 'generates unique branch names for the same task' do
      job = described_class.new
      
      # Call perform multiple times (though in practice this shouldn't happen)
      # and verify branch names are different each time
      branch_name_1 = job.send(:generate_branch_name, task)
      branch_name_2 = job.send(:generate_branch_name, task)
      
      expect(branch_name_1).not_to eq(branch_name_2)
      expect(branch_name_1).to start_with("cursor-agent/task-#{task.id}-")
      expect(branch_name_2).to start_with("cursor-agent/task-#{task.id}-")
    end
  end

  describe '#generate_webhook_url (private)' do
    it 'generates the correct webhook URL' do
      job = described_class.new
      webhook_url = job.send(:generate_webhook_url, task)
      
      expect(webhook_url).to eq("http://localhost:3000/webhooks/cursor/#{task.id}")
    end

    it 'uses APP_URL from environment' do
      allow(ENV).to receive(:fetch).with('APP_URL', anything).and_return('https://example.com')
      
      job = described_class.new
      webhook_url = job.send(:generate_webhook_url, task)
      
      expect(webhook_url).to eq("https://example.com/webhooks/cursor/#{task.id}")
    end
  end
end
