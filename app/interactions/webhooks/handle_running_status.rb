# frozen_string_literal: true

module Webhooks
  # HandleRunningStatus processes the RUNNING webhook status
  # Transitions pending tasks to running status
  class HandleRunningStatus < ApplicationInteraction
    record :task
    hash :payload, strip: false

    validates :task, presence: true

    def execute
      Rails.logger.info("[Webhook] Task #{task.id}: Handling RUNNING status")

      # Only update if not already running or beyond
      if task.pending?
        outcome = Tasks::UpdateStatus.run(
          task: task,
          new_status: 'running',
          log_message: 'Cursor agent is now running'
        )

        if outcome.valid?
          Rails.logger.info("[Webhook] Task #{task.id}: Successfully transitioned to running")
          { task: outcome.result }
        else
          Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
          errors.add(:base, outcome.errors.full_messages.join(', '))
        end
      else
        Rails.logger.info("[Webhook] Task #{task.id}: Already in #{task.status} status, skipping RUNNING update")
        { task: task, skipped: true }
      end
    end
  end
end
