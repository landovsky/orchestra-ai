require 'rails_helper'

RSpec.describe Epics::Start, type: :interaction do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:cursor_credential) { create(:credential, user: user, service_name: 'cursor_agent') }
  let(:epic) { create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential, status: :pending) }
  let!(:task1) { create(:task, epic: epic, position: 0, description: 'First task') }
  let!(:task2) { create(:task, epic: epic, position: 1, description: 'Second task') }

  describe '#execute' do
    context 'with valid inputs' do
      it 'updates epic status to running' do
        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).to be_valid
        expect(epic.reload.status).to eq('running')
      end

      it 'enqueues the first task execution job' do
        expect {
          described_class.run!(
            user: user,
            epic: epic
          )
        }.to have_enqueued_job(Tasks::ExecuteJob).with(task1.id)
      end

      it 'does not enqueue the second task' do
        expect {
          described_class.run!(
            user: user,
            epic: epic
          )
        }.not_to have_enqueued_job(Tasks::ExecuteJob).with(task2.id)
      end

      it 'returns the epic' do
        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).to be_valid
        expect(outcome.result).to eq(epic)
      end
    end

    context 'with invalid inputs' do
      it 'fails when epic does not belong to user' do
        outcome = described_class.run(
          user: other_user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('does not belong to the user')
      end

      it 'fails when epic is already running' do
        epic.update!(status: :running)

        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include("cannot be started from status 'running' (must be 'pending')")
      end

      it 'fails when epic is completed' do
        epic.update!(status: :completed)

        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include("cannot be started from status 'completed' (must be 'pending')")
      end

      it 'fails when epic is paused' do
        epic.update!(status: :paused)

        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include("cannot be started from status 'paused' (must be 'pending')")
      end

      it 'fails when epic has no cursor agent credential' do
        epic.update!(cursor_agent_credential: nil)

        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('does not have a Cursor agent credential configured')
      end

      it 'fails when epic has no tasks' do
        epic_without_tasks = create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential, status: :pending)

        outcome = described_class.run(
          user: user,
          epic: epic_without_tasks
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:epic]).to include('has no tasks to execute')
      end

      it 'does not change epic status when validation fails' do
        epic.update!(status: :completed)
        original_status = epic.status

        outcome = described_class.run(
          user: user,
          epic: epic
        )

        expect(outcome).not_to be_valid
        expect(epic.reload.status).to eq(original_status)
      end

      it 'does not enqueue job when validation fails' do
        epic.update!(cursor_agent_credential: nil)

        expect {
          described_class.run(
            user: user,
            epic: epic
          )
        }.not_to have_enqueued_job(Tasks::ExecuteJob)
      end
    end

    context 'transaction rollback' do
      it 'rolls back epic status change when job enqueue fails' do
        # Stub perform_later to raise an error
        allow(Tasks::ExecuteJob).to receive(:perform_later).and_raise(StandardError, 'Job enqueue failed')

        expect {
          described_class.run!(
            user: user,
            epic: epic
          )
        }.to raise_error(StandardError, 'Job enqueue failed')

        expect(epic.reload.status).to eq('pending')
      end
    end

    context 'with multiple tasks' do
      let!(:task3) { create(:task, epic: epic, position: 2, description: 'Third task') }

      it 'only enqueues the first task (lowest position)' do
        expect {
          described_class.run!(
            user: user,
            epic: epic
          )
        }.to have_enqueued_job(Tasks::ExecuteJob).with(task1.id).and(
          not_have_enqueued_job(Tasks::ExecuteJob).with(task2.id)
        ).and(
          not_have_enqueued_job(Tasks::ExecuteJob).with(task3.id)
        )
      end
    end

    context 'with tasks in different order' do
      let(:epic2) { create(:epic, user: user, repository: repository, cursor_agent_credential: cursor_credential, status: :pending) }
      let!(:task_pos_5) { create(:task, epic: epic2, position: 5, description: 'Position 5') }
      let!(:task_pos_1) { create(:task, epic: epic2, position: 1, description: 'Position 1') }
      let!(:task_pos_3) { create(:task, epic: epic2, position: 3, description: 'Position 3') }

      it 'enqueues the task with lowest position' do
        expect {
          described_class.run!(
            user: user,
            epic: epic2
          )
        }.to have_enqueued_job(Tasks::ExecuteJob).with(task_pos_1.id)
      end
    end
  end
end
