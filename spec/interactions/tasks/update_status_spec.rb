require 'rails_helper'

RSpec.describe Tasks::UpdateStatus, type: :interaction do
  let(:user) { create(:user) }
  let(:repository) { create(:repository, user: user) }
  let(:epic) { create(:epic, user: user, repository: repository) }
  let(:task) { create(:task, epic: epic, status: :pending) }

  describe '#execute' do
    context 'with valid inputs' do
      it 'updates task status' do
        outcome = described_class.run(
          task: task,
          new_status: 'running'
        )

        expect(outcome).to be_valid
        expect(outcome.result).to eq(task)
        expect(task.reload.status).to eq('running')
      end

      it 'updates PR URL when provided' do
        pr_url = 'https://github.com/user/repo/pull/123'
        
        outcome = described_class.run(
          task: task,
          new_status: 'pr_open',
          pr_url: pr_url
        )

        expect(outcome).to be_valid
        expect(task.reload.pr_url).to eq(pr_url)
      end

      it 'appends log message with timestamp' do
        log_message = 'Starting Cursor agent...'
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: log_message
        )

        expect(outcome).to be_valid
        task.reload
        expect(task.debug_log).to include(log_message)
        expect(task.debug_log).to match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/)
      end

      it 'appends to existing log without overwriting' do
        task.update!(debug_log: '[2025-01-01 10:00:00] First message')
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: 'Second message'
        )

        expect(outcome).to be_valid
        task.reload
        expect(task.debug_log).to include('First message')
        expect(task.debug_log).to include('Second message')
        expect(task.debug_log.lines.count).to eq(2)
      end

      it 'handles nil debug_log initially' do
        task.update_column(:debug_log, nil)
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: 'First log entry'
        )

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include('First log entry')
      end

      it 'updates status without log message' do
        outcome = described_class.run(
          task: task,
          new_status: 'completed'
        )

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('completed')
        expect(task.debug_log).to be_blank
      end

      it 'updates status without PR URL' do
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: 'Test'
        )

        expect(outcome).to be_valid
        expect(task.reload.pr_url).to be_nil
      end

      it 'can update all fields together' do
        outcome = described_class.run(
          task: task,
          new_status: 'pr_open',
          log_message: 'PR created',
          pr_url: 'https://github.com/user/repo/pull/456'
        )

        expect(outcome).to be_valid
        task.reload
        expect(task.status).to eq('pr_open')
        expect(task.debug_log).to include('PR created')
        expect(task.pr_url).to eq('https://github.com/user/repo/pull/456')
      end

      it 'transitions through multiple statuses' do
        # First update
        described_class.run!(task: task, new_status: 'running', log_message: 'Started')
        expect(task.reload.status).to eq('running')

        # Second update
        described_class.run!(task: task, new_status: 'pr_open', log_message: 'PR opened')
        expect(task.reload.status).to eq('pr_open')

        # Third update
        described_class.run!(task: task, new_status: 'completed', log_message: 'Merged')
        task.reload
        expect(task.status).to eq('completed')
        expect(task.debug_log.lines.count).to eq(3)
      end

      it 'supports all valid task statuses' do
        %w[pending running pr_open merging completed failed].each do |status|
          outcome = described_class.run(
            task: task,
            new_status: status
          )

          expect(outcome).to be_valid
          expect(task.reload.status).to eq(status)
        end
      end
    end

    context 'with invalid inputs' do
      it 'fails with invalid status' do
        outcome = described_class.run(
          task: task,
          new_status: 'invalid_status'
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:new_status]).to be_present
        expect(outcome.errors[:new_status].first).to match(/must be one of/)
      end

      it 'fails with empty status' do
        outcome = described_class.run(
          task: task,
          new_status: ''
        )

        expect(outcome).not_to be_valid
        expect(outcome.errors[:new_status]).to be_present
      end

      it 'does not modify task on validation failure' do
        original_status = task.status
        
        outcome = described_class.run(
          task: task,
          new_status: 'invalid_status',
          log_message: 'Should not appear'
        )

        expect(outcome).not_to be_valid
        task.reload
        expect(task.status).to eq(original_status)
        expect(task.debug_log).to be_blank
      end
    end

    context 'broadcasting' do
      it 'broadcasts task update to epic channel' do
        expect(task).to receive(:broadcast_replace_to).with(
          "epic_#{epic.id}",
          target: "task_#{task.id}",
          partial: "tasks/task",
          locals: { task: task }
        )

        described_class.run!(
          task: task,
          new_status: 'running'
        )
      end

      it 'continues execution even if broadcast fails' do
        allow(task).to receive(:broadcast_replace_to).and_raise(StandardError.new('Broadcast error'))
        allow(Rails.logger).to receive(:error)

        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: 'Test'
        )

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('running')
        expect(Rails.logger).to have_received(:error).with(/Failed to broadcast/)
      end
    end

    context 'transaction behavior' do
      it 'rolls back all changes if update fails' do
        # Make task update fail by stubbing
        allow(task).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          described_class.run(
            task: task,
            new_status: 'running',
            log_message: 'Should not persist'
          )
        }.to raise_error(ActiveRecord::RecordInvalid)

        task.reload
        expect(task.status).to eq('pending')
        expect(task.debug_log).to be_blank
      end
    end

    context 'log formatting' do
      it 'formats timestamp correctly' do
        freeze_time = Time.zone.parse('2025-10-29 14:30:45')
        
        travel_to freeze_time do
          outcome = described_class.run(
            task: task,
            new_status: 'running',
            log_message: 'Test message'
          )

          expect(outcome).to be_valid
          expect(task.reload.debug_log).to include('[2025-10-29 14:30:45] Test message')
        end
      end

      it 'preserves log message content exactly' do
        special_message = "Special chars: !@#$%^&*() and 'quotes' and \"double quotes\""
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: special_message
        )

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include(special_message)
      end

      it 'handles multiline log messages' do
        multiline_message = "Line 1\nLine 2\nLine 3"
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: multiline_message
        )

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to include(multiline_message)
      end
    end

    context 'edge cases' do
      it 'handles blank log message' do
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: ''
        )

        expect(outcome).to be_valid
        expect(task.reload.debug_log).to be_blank
      end

      it 'handles blank PR URL' do
        outcome = described_class.run(
          task: task,
          new_status: 'pr_open',
          pr_url: ''
        )

        expect(outcome).to be_valid
        expect(task.reload.pr_url).to be_nil
      end

      it 'can update to the same status' do
        task.update!(status: :running)
        
        outcome = described_class.run(
          task: task,
          new_status: 'running',
          log_message: 'Still running'
        )

        expect(outcome).to be_valid
        expect(task.reload.status).to eq('running')
      end
    end
  end
end
