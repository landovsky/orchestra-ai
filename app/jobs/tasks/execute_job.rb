# frozen_string_literal: true

module Tasks
  # ExecuteJob launches a Cursor agent for a task
  #
  # This job:
  # 1. Updates task status to 'running'
  # 2. Generates a unique branch name
  # 3. Launches the Cursor agent via CursorAgentService
  # 4. Saves the agent ID and branch name to the task
  # 5. Logs all steps for debugging
  class ExecuteJob < ApplicationJob
    queue_as :default

    # Perform the job
    #
    # @param task_id [Integer] The ID of the task to execute
    def perform(task_id)
      task = Task.find(task_id)
      
      # Update task status to running
      Tasks::UpdateStatus.run!(
        task: task,
        new_status: 'running',
        log_message: 'Starting task execution...'
      )

      # Get the Cursor agent credential from the epic
      credential = task.epic.cursor_agent_credential
      raise StandardError, 'No Cursor agent credential configured for epic' if credential.nil?

      # Generate branch name and webhook URL
      branch_name = generate_branch_name(task)
      webhook_url = generate_webhook_url(task)

      # Log the launch attempt
      Tasks::UpdateStatus.run!(
        task: task,
        new_status: 'running',
        log_message: "Launching Cursor agent for branch: #{branch_name}"
      )

      # Launch the Cursor agent
      cursor_service = Services::CursorAgentService.new(credential)
      result = cursor_service.launch_agent(
        task: task,
        webhook_url: webhook_url,
        branch_name: branch_name
      )

      # Extract agent ID from result
      agent_id = result['id']
      raise StandardError, 'No agent ID returned from Cursor API' if agent_id.blank?

      # Save agent ID and branch name to task
      task.update!(
        cursor_agent_id: agent_id,
        branch_name: branch_name
      )

      # Log successful launch
      Tasks::UpdateStatus.run!(
        task: task,
        new_status: 'running',
        log_message: "Cursor agent launched successfully. Agent ID: #{agent_id}"
      )

      Rails.logger.info("Task #{task.id}: Cursor agent launched with ID #{agent_id} on branch #{branch_name}")
    rescue StandardError => e
      # Log the error and update task status to failed
      error_message = "Failed to launch Cursor agent: #{e.message}"
      Rails.logger.error("Task #{task_id}: #{error_message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Try to update task status, but don't fail if task is missing
      begin
        task ||= Task.find(task_id)
        Tasks::UpdateStatus.run!(
          task: task,
          new_status: 'failed',
          log_message: error_message
        )
      rescue StandardError => update_error
        Rails.logger.error("Failed to update task status: #{update_error.message}")
      end

      # Re-raise the error so the job is marked as failed
      raise
    end

    private

    # Generate a unique branch name for the task
    #
    # Format: cursor-agent/task-{id}-{random}
    #
    # @param task [Task] The task object
    # @return [String] The generated branch name
    def generate_branch_name(task)
      random_suffix = SecureRandom.hex(4)
      "cursor-agent/task-#{task.id}-#{random_suffix}"
    end

    # Generate the webhook URL for Cursor callbacks
    #
    # @param task [Task] The task object
    # @return [String] The webhook URL
    def generate_webhook_url(task)
      # In development/test, you might use ngrok
      # In production, this would be your actual domain
      base_url = ENV.fetch('APP_URL', 'http://localhost:3000')
      "#{base_url}/webhooks/cursor/#{task.id}"
    end
  end
end
