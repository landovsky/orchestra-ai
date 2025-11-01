# frozen_string_literal: true

module Tasks
  # ExecuteJob launches a Cursor agent for a task
  #
  # This job delegates the actual execution logic to Tasks::Services::Execute
  # and is responsible for queuing the task execution in the background.
  class ExecuteJob < ApplicationJob
    queue_as :default

    # Perform the job
    #
    # @param task_id [Integer] The ID of the task to execute
    def perform(task_id)
      task = Task.find(task_id)
      
      # Delegate to the Execute service
      Tasks::Services::Execute.run!(task: task)
    end
  end
end
