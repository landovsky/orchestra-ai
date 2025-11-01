# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::ExecuteJob, type: :job do
  let(:user) { create(:user) }
  let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent', api_key: 'test-cursor-key') }
  let(:github_credential) { create(:credential, user: user, service_name: 'github', api_key: 'test-github-key') }
  let(:repository) { create(:repository, user: user, github_credential: github_credential) }
  let(:epic) { create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential, base_branch: 'main') }
  let(:task) { create(:task, epic: epic, status: 'pending') }

  let(:mock_execute_service) { instance_double(Tasks::Services::Execute) }
  let(:mock_result) { { task: task, agent_id: 'agent-abc123', branch_name: 'cursor-agent/task-1-abcd1234' } }

  before do
    # Mock the Execute service
    allow(Tasks::Services::Execute).to receive(:run!).with(task: task).and_return(mock_result)
  end

  describe '#perform' do
    it 'delegates to Tasks::Services::Execute' do
      described_class.new.perform(task.id)
      
      expect(Tasks::Services::Execute).to have_received(:run!).with(task: task)
    end

    context 'when task does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.new.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
