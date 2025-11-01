# frozen_string_literal: true

module Webhooks
  # HandleErrorStatus processes the ERROR webhook status
  # Transitions task to failed status with error message
  class HandleErrorStatus < ApplicationInteraction
    record :task
    hash :payload, strip: false

    validates :task, presence: true

    def execute
      Rails.logger.info("[Webhook] Task #{task.id}: Handling ERROR status")

      # Extract error message from payload if available
      error_message = extract_error_message

      outcome = Tasks::UpdateStatus.run(
        task: task,
        new_status: 'failed',
        log_message: "Cursor agent failed: #{error_message || 'Unknown error'}"
      )

      if outcome.valid?
        Rails.logger.info("[Webhook] Task #{task.id}: Successfully transitioned to failed")
        { task: outcome.result, error_message: error_message }
      else
        Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
        errors.add(:base, outcome.errors.full_messages.join(', '))
      end
    end

    private

    # Extract error message from webhook payload
    def extract_error_message
      # Try various common error message fields
      return payload['error_message'] || payload[:error_message] if payload['error_message'].present? || payload[:error_message].present?
      return payload['error'] || payload[:error] if payload['error'].present? || payload[:error].present?
      return payload.dig('data', 'error') || payload.dig(:data, :error) if payload.dig('data', 'error').present? || payload.dig(:data, :error).present?
      return payload['message'] || payload[:message] if payload['message'].present? || payload[:message].present?

      nil
    end
  end
end
