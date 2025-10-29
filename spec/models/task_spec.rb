require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'associations' do
    it { should belong_to(:epic) }
  end

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:position) }
    it { should validate_presence_of(:epic) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, running: 1, pr_open: 2, merging: 3, completed: 4, failed: 5).backed_by_column_of_type(:integer) }

    it 'defaults to pending status' do
      task = build(:task, status: nil)
      expect(task.status).to eq('pending')
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      let(:epic) { create(:epic) }
      let!(:task3) { create(:task, epic: epic, position: 2) }
      let!(:task1) { create(:task, epic: epic, position: 0) }
      let!(:task2) { create(:task, epic: epic, position: 1) }

      it 'returns tasks ordered by position ascending' do
        expect(Task.ordered).to eq([task1, task2, task3])
      end
    end
  end

  describe 'status transitions' do
    let(:task) { create(:task) }

    it 'can transition from pending to running' do
      task.update(status: :running)
      expect(task.running?).to be true
    end

    it 'can transition from running to pr_open' do
      task.update(status: :running)
      task.update(status: :pr_open)
      expect(task.pr_open?).to be true
    end

    it 'can transition from pr_open to merging' do
      task.update(status: :pr_open)
      task.update(status: :merging)
      expect(task.merging?).to be true
    end

    it 'can transition from merging to completed' do
      task.update(status: :merging)
      task.update(status: :completed)
      expect(task.completed?).to be true
    end

    it 'can transition to failed from any state' do
      task.update(status: :running)
      task.update(status: :failed)
      expect(task.failed?).to be true
    end
  end

  describe 'attributes' do
    let(:task) { create(:task) }

    it 'can store cursor_agent_id' do
      task.update(cursor_agent_id: 'agent-123')
      expect(task.cursor_agent_id).to eq('agent-123')
    end

    it 'can store pr_url' do
      task.update(pr_url: 'https://github.com/user/repo/pull/123')
      expect(task.pr_url).to eq('https://github.com/user/repo/pull/123')
    end

    it 'can store branch_name' do
      task.update(branch_name: 'feature/task-1')
      expect(task.branch_name).to eq('feature/task-1')
    end

    it 'can store debug_log' do
      log_message = 'Error: Something went wrong'
      task.update(debug_log: log_message)
      expect(task.debug_log).to eq(log_message)
    end
  end
end
