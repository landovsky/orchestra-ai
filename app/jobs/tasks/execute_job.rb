module Tasks
  class ExecuteJob < ApplicationJob
    queue_as :default

    def perform(task_id)
      # Stub implementation for Task 4.3
      # This will be fully implemented in Phase 5.1
      task = Task.find(task_id)
      Rails.logger.info("Tasks::ExecuteJob enqueued for task #{task_id}: #{task.description}")
      
      # Future implementation will:
      # 1. Call Tasks::UpdateStatus to mark as 'running'
      # 2. Generate branch_name
      # 3. Generate webhook_url
      # 4. Call CursorAgentService.launch_agent
      # 5. Update task with cursor_agent_id and branch_name
    end
  end
end
