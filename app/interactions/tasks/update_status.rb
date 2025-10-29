module Tasks
  class UpdateStatus < ActiveInteraction::Base
    record :task
    string :new_status
    string :log_message, default: nil
    string :pr_url, default: nil

    validates :new_status, presence: true
    validate :validate_status_value

    def execute
      ActiveRecord::Base.transaction do
        # Update task status
        task.update!(status: new_status)

        # Update PR URL if provided
        task.update!(pr_url: pr_url) if pr_url.present?

        # Append log message if provided
        if log_message.present?
          append_to_debug_log(log_message)
        end

        # Broadcast Turbo Stream update
        broadcast_task_update

        # Return the updated task
        task
      end
    end

    private

    def validate_status_value
      valid_statuses = Task.statuses.keys
      unless valid_statuses.include?(new_status)
        errors.add(:new_status, "must be one of: #{valid_statuses.join(', ')}")
      end
    end

    def append_to_debug_log(message)
      timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
      log_entry = "[#{timestamp}] #{message}"
      
      current_log = task.debug_log.to_s
      updated_log = current_log.blank? ? log_entry : "#{current_log}\n#{log_entry}"
      
      task.update!(debug_log: updated_log)
    end

    def broadcast_task_update
      # Broadcast to the epic's Turbo Stream channel
      task.broadcast_replace_to(
        "epic_#{task.epic_id}",
        target: "task_#{task.id}",
        partial: "tasks/task",
        locals: { task: task }
      )
    rescue => e
      # Log broadcast errors but don't fail the transaction
      Rails.logger.error("Failed to broadcast task update: #{e.message}")
    end
  end
end
