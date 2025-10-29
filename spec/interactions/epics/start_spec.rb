require 'rails_helper'

RSpec.describe Epics::Start, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository, status: :pending) }
  
  # Create some tasks for the epic
  let!(:task1) { create(:task, epic: epic, position: 0, status: :pending, description: 'First task') }
  let!(:task2) { create(:task, epic: epic, position: 1, status: :pending, description: 'Second task') }
  let!(:task3) { create(:task, epic: epic, position: 2, status: :pending, description: 'Third task') }

  describe '#execute' do
    context 'with valid inputs' do
      it 'updates epic status to running' do
        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).to be_valid
        expect(epic.reload.status).to eq('running')
      end

      it 'returns the updated epic' do
        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).to be_valid
        expect(outcome.result).to eq(epic)
        expect(outcome.result.status).to eq('running')
      end

      it 'enqueues Tasks::ExecuteJob for the first pending task' do
        expect(Tasks::ExecuteJob).to receive(:perform_async).with(task1.id)

        outcome = described_class.run(user: user, epic: epic)
        expect(outcome).to be_valid
      end

      it 'enqueues job for task with lowest position' do
        # Create tasks out of order
        epic2 = create(:epic, user: user, repository: repository, status: :pending)
        task_high = create(:task, epic: epic2, position: 10, status: :pending)
        task_low = create(:task, epic: epic2, position: 1, status: :pending)
        task_mid = create(:task, epic: epic2, position: 5, status: :pending)

        expect(Tasks::ExecuteJob).to receive(:perform_async).with(task_low.id)

        described_class.run!(user: user, epic: epic2)
      end

      it 'only enqueues job for pending tasks, not completed ones' do
        # Mark first task as completed
        task1.update!(status: :completed)

        expect(Tasks::ExecuteJob).to receive(:perform_async).with(task2.id)

        described_class.run!(user: user, epic: epic)
      end

      it 'broadcasts epic update via Turbo Streams' do
        expect(epic).to receive(:broadcast_replace_to).with(
          "epic_#{epic.id}",
          target: "epic_#{epic.id}",
          partial: "epics/epic",
          locals: { epic: epic }
        )

        described_class.run!(user: user, epic: epic)
      end

      it 'succeeds even if broadcast fails' do
        allow(epic).to receive(:broadcast_replace_to).and_raise(StandardError.new("Broadcast error"))
        allow(Rails.logger).to receive(:error)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).to be_valid
        expect(epic.reload.status).to eq('running')
        expect(Rails.logger).to have_received(:error).with(/Failed to broadcast epic update/)
      end
    end

    context 'with invalid epic status' do
      it 'fails when epic is already running' do
        epic.update!(status: :running)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must be in pending status to start')
      end

      it 'fails when epic is completed' do
        epic.update!(status: :completed)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must be in pending status to start')
      end

      it 'fails when epic is failed' do
        epic.update!(status: :failed)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must be in pending status to start')
      end

      it 'fails when epic is paused' do
        epic.update!(status: :paused)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must be in pending status to start')
      end

      it 'fails when epic is generating_spec' do
        epic.update!(status: :generating_spec)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must be in pending status to start')
      end
    end

    context 'with invalid epic ownership' do
      it 'fails when epic does not belong to user' do
        other_user = create(:user)

        outcome = described_class.run(user: other_user, epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must belong to the user')
      end
    end

    context 'with epic that has no tasks' do
      it 'fails when epic has no tasks' do
        empty_epic = create(:epic, user: user, repository: repository, status: :pending)

        outcome = described_class.run(user: user, epic: empty_epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('must have at least one task')
      end
    end

    context 'with epic that has no pending tasks' do
      it 'updates epic to running but does not enqueue job' do
        # Mark all tasks as completed
        task1.update!(status: :completed)
        task2.update!(status: :completed)
        task3.update!(status: :completed)

        expect(Tasks::ExecuteJob).not_to receive(:perform_async)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).to be_valid
        expect(epic.reload.status).to eq('running')
      end
    end

    context 'transaction rollback' do
      it 'rolls back epic status change if job enqueuing fails' do
        allow(Tasks::ExecuteJob).to receive(:perform_async).and_raise(StandardError.new("Job error"))

        expect {
          described_class.run!(user: user, epic: epic)
        }.to raise_error(StandardError, "Job error")

        expect(epic.reload.status).to eq('pending')
      end
    end

    context 'with required parameters' do
      it 'requires user parameter' do
        outcome = described_class.run(epic: epic)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:user]).to be_present
      end

      it 'requires epic parameter' do
        outcome = described_class.run(user: user)

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to be_present
      end
    end

    context 'integration with multiple epics' do
      it 'only affects the specified epic' do
        epic2 = create(:epic, user: user, repository: repository, status: :pending)
        task_epic2 = create(:task, epic: epic2, position: 0, status: :pending)

        outcome = described_class.run(user: user, epic: epic)

        expect(outcome).to be_valid
        expect(epic.reload.status).to eq('running')
        expect(epic2.reload.status).to eq('pending')
      end

      it 'can start multiple epics sequentially' do
        epic2 = create(:epic, user: user, repository: repository, status: :pending)
        task_epic2 = create(:task, epic: epic2, position: 0, status: :pending)

        outcome1 = described_class.run(user: user, epic: epic)
        outcome2 = described_class.run(user: user, epic: epic2)

        expect(outcome1).to be_valid
        expect(outcome2).to be_valid
        expect(epic.reload.status).to eq('running')
        expect(epic2.reload.status).to eq('running')
      end
    end

    context 'with mixed task statuses' do
      it 'enqueues the first pending task when some are running' do
        task1.update!(status: :running)
        
        expect(Tasks::ExecuteJob).to receive(:perform_async).with(task2.id)

        described_class.run!(user: user, epic: epic)
      end

      it 'enqueues the first pending task when some are failed' do
        task1.update!(status: :failed)
        
        expect(Tasks::ExecuteJob).to receive(:perform_async).with(task2.id)

        described_class.run!(user: user, epic: epic)
      end

      it 'enqueues the first pending task by position, not creation order' do
        # Create tasks in reverse order but with correct positions
        epic2 = create(:epic, user: user, repository: repository, status: :pending)
        
        # Create in reverse order
        last = create(:task, epic: epic2, position: 2, status: :pending, description: 'Last')
        middle = create(:task, epic: epic2, position: 1, status: :pending, description: 'Middle')
        first = create(:task, epic: epic2, position: 0, status: :pending, description: 'First')

        expect(Tasks::ExecuteJob).to receive(:perform_async).with(first.id)

        described_class.run!(user: user, epic: epic2)
      end
    end

    context 'edge cases' do
      it 'handles epic with single task' do
        single_task_epic = create(:epic, user: user, repository: repository, status: :pending)
        single_task = create(:task, epic: single_task_epic, position: 0, status: :pending)

        expect(Tasks::ExecuteJob).to receive(:perform_async).with(single_task.id)

        outcome = described_class.run(user: user, epic: single_task_epic)

        expect(outcome).to be_valid
        expect(single_task_epic.reload.status).to eq('running')
      end

      it 'handles epic with many tasks' do
        many_task_epic = create(:epic, user: user, repository: repository, status: :pending)
        tasks = (0..9).map do |i|
          create(:task, epic: many_task_epic, position: i, status: :pending)
        end

        expect(Tasks::ExecuteJob).to receive(:perform_async).with(tasks.first.id)

        outcome = described_class.run(user: user, epic: many_task_epic)

        expect(outcome).to be_valid
        expect(many_task_epic.reload.status).to eq('running')
      end
    end
  end
end
