# frozen_string_literal: true

# WebhooksController handles incoming webhook callbacks from external services
# Currently supports Cursor agent status updates
class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, if: :devise_configured?

  # POST /webhooks/cursor/:task_id
  # Receives status updates from Cursor agent API
  # Expected statuses: RUNNING, FINISHED, ERROR
  def cursor
    task_id = params[:task_id]
    task = Task.find_by(id: task_id)

    if task.nil?
      log_webhook_error("Task not found: #{task_id}", params)
      render json: { error: 'Task not found' }, status: :not_found
      return
    end

    # Log the incoming webhook payload
    log_webhook_received(task, params)

    # Extract status from payload
    status = extract_status(params)
    
    if status.nil?
      log_webhook_error("Invalid webhook payload - missing status", params)
      render json: { error: 'Invalid payload' }, status: :bad_request
      return
    end

    # Handle the webhook status
    case status.upcase
    when 'FINISHED'
      handle_finished_status(task, params)
    when 'RUNNING'
      handle_running_status(task, params)
    when 'ERROR'
      handle_error_status(task, params)
    else
      Rails.logger.warn("[Webhook] Task #{task_id}: Unknown status #{status}")
    end

    # Render success response
    render json: { success: true, task_id: task_id, status: status }, status: :ok
  rescue StandardError => e
    log_webhook_error("Unexpected error: #{e.message}", params)
    Rails.logger.error("Webhook error: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  private

  def devise_configured?
    defined?(Devise)
  end

  # Extract status from webhook payload
  # Supports multiple payload formats
  def extract_status(params)
    # Try direct status parameter
    return params[:status] if params[:status].present?

    # Try nested data structure
    return params.dig(:data, :status) if params.dig(:data, :status).present?

    # Try event type
    return params[:event] if params[:event].present?

    nil
  end

  # Log webhook receipt with full details
  def log_webhook_received(task, params)
    Rails.logger.info("=" * 80)
    Rails.logger.info("[Webhook] Cursor callback received")
    Rails.logger.info("-" * 80)
    Rails.logger.info("Task ID: #{task.id}")
    Rails.logger.info("Task Description: #{task.description}")
    Rails.logger.info("Task Status: #{task.status}")
    Rails.logger.info("-" * 80)
    Rails.logger.info("Payload:")
    Rails.logger.info(JSON.pretty_generate(sanitize_params(params)))
    Rails.logger.info("=" * 80)
  end

  # Log webhook errors
  def log_webhook_error(message, params)
    Rails.logger.error("=" * 80)
    Rails.logger.error("[Webhook ERROR] #{message}")
    Rails.logger.error("-" * 80)
    Rails.logger.error("Payload:")
    Rails.logger.error(JSON.pretty_generate(sanitize_params(params)))
    Rails.logger.error("=" * 80)
  end

  # Sanitize params for logging (remove Rails internal params)
  def sanitize_params(params)
    params.to_unsafe_h.except('controller', 'action', 'task_id', 'format')
  end

  # Handle FINISHED webhook status
  # Transitions task to pr_open and saves PR URL
  def handle_finished_status(task, params)
    Rails.logger.info("[Webhook] Task #{task.id}: Handling FINISHED status")
    
    # Extract PR URL from webhook payload
    pr_url = extract_pr_url(params)
    
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
    else
      Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
    end
  end

  # Handle RUNNING webhook status
  def handle_running_status(task, params)
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
      else
        Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
      end
    else
      Rails.logger.info("[Webhook] Task #{task.id}: Already in #{task.status} status, skipping RUNNING update")
    end
  end

  # Handle ERROR webhook status
  def handle_error_status(task, params)
    Rails.logger.info("[Webhook] Task #{task.id}: Handling ERROR status")
    
    # Extract error message from payload if available
    error_message = extract_error_message(params)
    
    outcome = Tasks::UpdateStatus.run(
      task: task,
      new_status: 'failed',
      log_message: "Cursor agent failed: #{error_message || 'Unknown error'}"
    )

    if outcome.valid?
      Rails.logger.info("[Webhook] Task #{task.id}: Successfully transitioned to failed")
    else
      Rails.logger.error("[Webhook] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
    end
  end

  # Extract PR URL from webhook payload
  # Supports multiple payload formats
  def extract_pr_url(params)
    # Try nested target structure (Cursor API format)
    return params.dig(:target, :prUrl) if params.dig(:target, :prUrl).present?
    return params.dig(:target, :pr_url) if params.dig(:target, :pr_url).present?
    
    # Try direct PR URL parameter
    return params[:pr_url] if params[:pr_url].present?
    return params[:prUrl] if params[:prUrl].present?
    
    # Try data structure
    return params.dig(:data, :pr_url) if params.dig(:data, :pr_url).present?
    return params.dig(:data, :prUrl) if params.dig(:data, :prUrl).present?
    
    nil
  end

  # Extract error message from webhook payload
  def extract_error_message(params)
    # Try various common error message fields
    return params[:error_message] if params[:error_message].present?
    return params[:error] if params[:error].present?
    return params.dig(:data, :error) if params.dig(:data, :error).present?
    return params[:message] if params[:message].present?
    
    nil
  end
end
