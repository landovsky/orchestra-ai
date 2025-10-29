module Epics
  class Start < ActiveInteraction::Base
    object :user, class: User
    object :epic, class: Epic

    validates :epic, presence: true
    validate :validate_epic_is_pending
    validate :validate_epic_belongs_to_user
    validate :validate_epic_has_tasks

    def execute
      ActiveRecord::Base.transaction do
        # Update epic status to running
        epic.update!(status: :running)

        # Find the first pending task
        first_task = epic.tasks.where(status: :pending).order(position: :asc).first

        if first_task
          # Enqueue the job to execute the first task
          Tasks::ExecuteJob.perform_async(first_task.id)

          # Broadcast epic update via Turbo Streams
          broadcast_epic_update
        end

        # Return the updated epic
        epic
      end
    end

    private

    def validate_epic_is_pending
      unless epic&.pending?
        errors.add(:epic, 'must be in pending status to start')
      end
    end

    def validate_epic_belongs_to_user
      unless epic&.user_id == user&.id
        errors.add(:epic, 'must belong to the user')
      end
    end

    def validate_epic_has_tasks
      if epic && epic.tasks.empty?
        errors.add(:epic, 'must have at least one task')
      end
    end

    def broadcast_epic_update
      # Broadcast to the epic's Turbo Stream channel
      epic.broadcast_replace_to(
        "epic_#{epic.id}",
        target: "epic_#{epic.id}",
        partial: "epics/epic",
        locals: { epic: epic }
      )
    rescue => e
      # Log broadcast errors but don't fail the transaction
      Rails.logger.error("Failed to broadcast epic update: #{e.message}")
    end
  end
end
