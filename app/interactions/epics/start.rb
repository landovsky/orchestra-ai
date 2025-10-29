module Epics
  class Start < ActiveInteraction::Base
    record :user
    record :epic

    validates :epic, presence: true
    validate :validate_epic_belongs_to_user
    validate :validate_epic_can_be_started
    validate :validate_cursor_agent_credential

    def execute
      ActiveRecord::Base.transaction do
        # Update epic status to running
        epic.update!(status: :running)

        # Get the first task (lowest position)
        first_task = epic.tasks.ordered.first
        
        if first_task.nil?
          errors.add(:epic, 'has no tasks to execute')
          raise ActiveRecord::Rollback
        end

        # Enqueue the first task's execution job
        Tasks::ExecuteJob.perform_later(first_task.id)

        # Return the epic
        epic
      end
    end

    private

    def validate_epic_belongs_to_user
      unless epic.user_id == user.id
        errors.add(:epic, 'does not belong to the user')
      end
    end

    def validate_epic_can_be_started
      unless epic.pending?
        errors.add(:epic, "cannot be started from status '#{epic.status}' (must be 'pending')")
      end
    end

    def validate_cursor_agent_credential
      if epic.cursor_agent_credential_id.nil?
        errors.add(:epic, 'does not have a Cursor agent credential configured')
      end
    end
  end
end
