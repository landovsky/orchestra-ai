# frozen_string_literal: true

# WebhooksController handles incoming webhook callbacks from external services
# Currently supports Cursor agent status updates
# Business logic is delegated to ApplicationInteraction objects
class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token

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

    # Delegate to interaction for business logic
    outcome = Webhooks::ProcessCursorStatus.run(
      task: task,
      payload: sanitize_params(params)
    )

    if outcome.valid?
      result = outcome.result
      render json: { 
        success: true, 
        task_id: task_id, 
        status: result[:status] 
      }, status: :ok
    else
      log_webhook_error(outcome.errors.full_messages.join(', '), params)
      render json: { error: outcome.errors.full_messages.join(', ') }, status: :bad_request
    end
  rescue StandardError => e
    log_webhook_error("Unexpected error: #{e.message}", params)
    Rails.logger.error("Webhook error: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  private

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
end
