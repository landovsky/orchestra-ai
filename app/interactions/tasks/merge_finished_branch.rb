# frozen_string_literal: true

module Tasks
  # MergeFinishedBranch handles the business logic for merging a feature branch
  # into the base branch after a task is completed
  class MergeFinishedBranch < ApplicationInteraction
    record :task

    validates :task, presence: true
    validate :validate_task_state

    def execute
      Rails.logger.info("[Merge] Task #{task.id}: Starting merge process for branch '#{task.branch_name}'")

      # Get GitHub credential from repository
      github_service = Services::GithubService.new(task.epic.repository.github_credential)

      # Merge the pull request
      begin
        merge_sha = github_service.merge_pull_request(task)
        Rails.logger.info("[Merge] Task #{task.id}: Successfully merged PR. SHA: #{merge_sha}")
      rescue StandardError => e
        Rails.logger.error("[Merge] Task #{task.id}: Failed to merge PR: #{e.message}")
        errors.add(:base, "Failed to merge pull request: #{e.message}")
        return
      end

      # Delete the feature branch after merge
      begin
        github_service.delete_branch(task)
        Rails.logger.info("[Merge] Task #{task.id}: Successfully deleted branch '#{task.branch_name}'")
      rescue StandardError => e
        Rails.logger.warn("[Merge] Task #{task.id}: Failed to delete branch: #{e.message}")
        # Don't fail the interaction if branch deletion fails - the merge succeeded
      end

      # Update task status to merging
      outcome = Tasks::UpdateStatus.run(
        task: task,
        new_status: 'merging',
        log_message: "PR merged successfully. SHA: #{merge_sha}"
      )

      unless outcome.valid?
        Rails.logger.error("[Merge] Task #{task.id}: Failed to update status: #{outcome.errors.full_messages.join(', ')}")
        errors.add(:base, "Failed to update task status: #{outcome.errors.full_messages.join(', ')}")
        return
      end

      Rails.logger.info("[Merge] Task #{task.id}: Merge process completed successfully")
      
      { task: outcome.result, merge_sha: merge_sha }
    end

    private

    def validate_task_state
      if task.blank?
        errors.add(:task, 'cannot be blank')
        return
      end

      if task.branch_name.blank?
        errors.add(:task, 'must have a branch name')
      end

      if task.epic.nil?
        errors.add(:task, 'must belong to an epic')
        return
      end

      if task.epic.repository.nil?
        errors.add(:task, 'must have a repository')
        return
      end

      if task.epic.repository.github_credential.nil?
        errors.add(:task, 'repository must have GitHub credentials')
      end

      unless task.pr_open?
        errors.add(:task, "must be in pr_open status to merge (current: #{task.status})")
      end
    end
  end
end
