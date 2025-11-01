# frozen_string_literal: true

module Webhooks
  # HandleFinishedStatus processes the FINISHED webhook status
  # Transitions task to pr_open and saves PR URL
  class HandleFinishedStatus < ApplicationInteraction
    record :task
    hash :payload, strip: false

    validates :task, presence: true

    def execute
      Rails.logger.info("[Webhook] Task #{task.id}: Handling FINISHED status")

      # Extract PR URL from webhook payload
      pr_url = extract_pr_url

      if pr_url.blank?
        Rails.logger.warn("[Webhook] Task #{task.id}: No PR URL found in FINISHED webhook")
      end

      # Update task status using the interaction
      outcome = Tasks::UpdateStatus.run(
        task: task,
        new_status: 'pr_open',
        log_message: "Cursor agent finished. PR created: #{pr_url || 'URL not provided'}",
        pr_url: pr_url
      )

      if outcome.valid?
        Rails.logger.info("[Webhook] Task #{task.id}: Successfully transitioned to pr_open")
        
        # Enqueue merge job to merge the feature branch
        Tasks::MergeJob.perform_later(task.id)
        Rails.logger.info("[Webhook] Task #{task.id}: Merge job enqueued")
        
        { task: outcome.result, pr_url: pr_url }
      else
        Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
        errors.add(:base, outcome.errors.full_messages.join(', '))
      end
    end

    private

    # Extract PR URL from webhook payload
    # Supports multiple payload formats
    def extract_pr_url
      # Try nested target structure (Cursor API format)
      return payload.dig('target', 'prUrl') || payload.dig(:target, :prUrl) if payload.dig('target', 'prUrl').present? || payload.dig(:target, :prUrl).present?
      return payload.dig('target', 'pr_url') || payload.dig(:target, :pr_url) if payload.dig('target', 'pr_url').present? || payload.dig(:target, :pr_url).present?

      # Try direct PR URL parameter
      return payload['pr_url'] || payload[:pr_url] if payload['pr_url'].present? || payload[:pr_url].present?
      return payload['prUrl'] || payload[:prUrl] if payload['prUrl'].present? || payload[:prUrl].present?

      # Try data structure
      return payload.dig('data', 'pr_url') || payload.dig(:data, :pr_url) if payload.dig('data', 'pr_url').present? || payload.dig(:data, :pr_url).present?
      return payload.dig('data', 'prUrl') || payload.dig(:data, :prUrl) if payload.dig('data', 'prUrl').present? || payload.dig(:data, :prUrl).present?

      nil
    end
  end
end
