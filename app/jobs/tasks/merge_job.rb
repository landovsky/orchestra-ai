# frozen_string_literal: true

module Tasks
  # MergeJob handles the asynchronous merging of a feature branch
  # into the base branch after a task is completed
  #
  # This job delegates the actual merge logic to Tasks::MergeFinishedBranch
  # and is responsible for queuing the merge operation in the background.
  class MergeJob < ApplicationJob
    queue_as :default

    # Perform the job
    #
    # @param task_id [Integer] The ID of the task whose branch should be merged
    def perform(task_id)
      task = Task.find(task_id)
      
      # Delegate to the MergeFinishedBranch interaction
      outcome = Tasks::MergeFinishedBranch.run(task: task)

      if outcome.valid?
        Rails.logger.info("[MergeJob] Task #{task_id}: Merge completed successfully")
      else
        Rails.logger.error("[MergeJob] Task #{task_id}: Merge failed: #{outcome.errors.full_messages.join(', ')}")
        # Re-raise to trigger retry mechanism if configured
        raise StandardError, "Merge failed: #{outcome.errors.full_messages.join(', ')}"
      end
    end
  end
end
