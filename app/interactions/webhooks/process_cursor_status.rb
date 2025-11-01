# frozen_string_literal: true

module Webhooks
  # ProcessCursorStatus handles the business logic for processing Cursor webhook status updates
  # It extracts and validates the status, then delegates to the appropriate handler interaction
  class ProcessCursorStatus < ApplicationInteraction
    hash :payload, strip: false
    record :task

    validates :task, presence: true

    def execute
      # Extract status from payload
      status = extract_status

      if status.nil?
        errors.add(:base, 'Invalid webhook payload - missing status')
        return
      end

      # Handle the webhook status
      case status.upcase
      when 'FINISHED'
        handle_finished_status
      when 'RUNNING'
        handle_running_status
      when 'ERROR'
        handle_error_status
      else
        Rails.logger.warn("[Webhook] Task #{task.id}: Unknown status #{status}")
      end

      { task: task, status: status }
    end

    private

    def extract_status
      # Try direct status parameter
      return payload['status'] || payload[:status] if payload['status'].present? || payload[:status].present?

      # Try nested data structure
      return payload.dig('data', 'status') || payload.dig(:data, :status) if payload.dig('data', 'status').present? || payload.dig(:data, :status).present?

      # Try event type
      return payload['event'] || payload[:event] if payload['event'].present? || payload[:event].present?

      nil
    end

    def handle_finished_status
      outcome = Webhooks::HandleFinishedStatus.run(
        task: task,
        payload: payload
      )

      unless outcome.valid?
        errors.add(:base, "Failed to handle finished status: #{outcome.errors.full_messages.join(', ')}")
      end
    end

    def handle_running_status
      outcome = Webhooks::HandleRunningStatus.run(
        task: task,
        payload: payload
      )

      unless outcome.valid?
        errors.add(:base, "Failed to handle running status: #{outcome.errors.full_messages.join(', ')}")
      end
    end

    def handle_error_status
      outcome = Webhooks::HandleErrorStatus.run(
        task: task,
        payload: payload
      )

      unless outcome.valid?
        errors.add(:base, "Failed to handle error status: #{outcome.errors.full_messages.join(', ')}")
      end
    end
  end
end
