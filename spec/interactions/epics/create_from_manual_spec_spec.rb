require 'rails_helper'

RSpec.describe Epics::CreateFromManualSpec, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent') }
  let(:base_branch) { 'main' }
  let(:task_descriptions) { ['Task 1: Setup database', 'Task 2: Add API endpoints', 'Task 3: Write tests'] }
  let(:tasks_json) { task_descriptions.to_json }

  describe '#execute' do
    context 'with valid inputs' do
      it 'creates an epic with pending status' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch,
          cursor_agent_credential_id: cursor_credential.id
        )

        expect(outcome).to be_valid
        expect(outcome.result[:epic]).to be_persisted
        expect(outcome.result[:epic].status).to eq('pending')
        expect(outcome.result[:epic].base_branch).to eq(base_branch)
        expect(outcome.result[:epic].user).to eq(user)
        expect(outcome.result[:epic].repository).to eq(repository)
        expect(outcome.result[:epic].cursor_agent_credential_id).to eq(cursor_credential.id)
      end

      it 'creates tasks with correct descriptions' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        expect(outcome.result[:tasks].size).to eq(3)
        expect(outcome.result[:tasks].map(&:description)).to eq(task_descriptions)
      end

      it 'creates tasks with correct positions' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        tasks = outcome.result[:tasks]
        
        expect(tasks[0].position).to eq(0)
        expect(tasks[1].position).to eq(1)
        expect(tasks[2].position).to eq(2)
      end

      it 'creates tasks in correct order in database' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        epic = outcome.result[:epic]
        
        # Reload to ensure we're getting from DB
        epic.reload
        ordered_tasks = epic.tasks.ordered
        
        expect(ordered_tasks.first.description).to eq('Task 1: Setup database')
        expect(ordered_tasks.second.description).to eq('Task 2: Add API endpoints')
        expect(ordered_tasks.third.description).to eq('Task 3: Write tests')
      end

      it 'generates a title from the first task' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        expect(outcome.result[:epic].title).to eq('Task 1: Setup database')
      end

      it 'truncates long titles' do
        long_task = 'A' * 100
        long_tasks_json = [long_task, 'Task 2'].to_json

        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: long_tasks_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        expect(outcome.result[:epic].title).to eq("#{long_task[0..47]}...")
        expect(outcome.result[:epic].title.length).to eq(51)
      end

      it 'uses default base_branch when not provided' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json
        )

        expect(outcome).to be_valid
        expect(outcome.result[:epic].base_branch).to eq('main')
      end

      it 'allows custom base_branch' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: 'develop'
        )

        expect(outcome).to be_valid
        expect(outcome.result[:epic].base_branch).to eq('develop')
      end
    end

    context 'with invalid inputs' do
      it 'fails with invalid JSON' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: 'not valid json',
          base_branch: base_branch
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:tasks_json]).to be_present
        expect(outcome.errors[:tasks_json].first).to match(/must be valid JSON/)
      end

      it 'fails when tasks_json is not an array' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: '{"task": "value"}',
          base_branch: base_branch
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:tasks_json]).to include('must be a JSON array')
      end

      it 'fails when tasks array is empty' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: '[]',
          base_branch: base_branch
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:tasks_json]).to include('must contain at least one task')
      end

      it 'fails when a task is not a string' do
        invalid_tasks = ['Task 1', 123, 'Task 3'].to_json

        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: invalid_tasks,
          base_branch: base_branch
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:tasks_json]).to include('task at index 1 must be a string')
      end

      it 'fails when a task is blank' do
        invalid_tasks = ['Task 1', '   ', 'Task 3'].to_json

        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: invalid_tasks,
          base_branch: base_branch
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:tasks_json]).to include('task at index 1 cannot be blank')
      end

      it 'fails when cursor_agent_credential does not belong to user' do
        other_user = create(:user)
        other_credential = create(:credential, user: other_user, service_name: 'cursor_agent')

        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch,
          cursor_agent_credential_id: other_credential.id
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:cursor_agent_credential_id]).to include('must belong to the user')
      end

      it 'fails when cursor_agent_credential is not a cursor_agent type' do
        wrong_credential = create(:credential, user: user, service_name: 'github')

        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch,
          cursor_agent_credential_id: wrong_credential.id
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:cursor_agent_credential_id]).to include('must be a cursor_agent credential')
      end

      it 'fails when cursor_agent_credential_id does not exist' do
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: tasks_json,
          base_branch: base_branch,
          cursor_agent_credential_id: 99999
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:cursor_agent_credential_id]).to include('must belong to the user')
      end
    end

    context 'transaction rollback' do
      it 'does not create epic or tasks if task creation fails' do
        # Stub Task.create! to fail
        allow(Task).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          described_class.run(
            user: user,
            repository: repository,
            tasks_json: tasks_json,
            base_branch: base_branch
          )
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Epic.count).to eq(0)
        expect(Task.count).to eq(0)
      end
    end

    context 'with large task arrays' do
      it 'handles 10 tasks correctly' do
        large_task_list = (1..10).map { |i| "Task #{i}: Do something" }
        
        outcome = described_class.run(
          user: user,
          repository: repository,
          tasks_json: large_task_list.to_json,
          base_branch: base_branch
        )

        expect(outcome).to be_valid
        expect(outcome.result[:tasks].size).to eq(10)
        
        # Verify positions are sequential
        positions = outcome.result[:tasks].map(&:position)
        expect(positions).to eq((0..9).to_a)
      end
    end
  end
end
