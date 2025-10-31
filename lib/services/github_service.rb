# frozen_string_literal: true

module Services
  # GithubService wraps the Octokit client for interacting with the GitHub API
  # This service handles operations like merging PRs, deleting branches, and
  # inferring repository configuration.
  class GithubService
    attr_reader :client, :credential

    # Initialize a new GithubService instance
    #
    # @param credential [Credential] The credential object containing the GitHub API token
    # @raise [ArgumentError] if credential is nil or doesn't have an api_key
    def initialize(credential)
      raise ArgumentError, 'Credential cannot be nil' if credential.nil?
      raise ArgumentError, 'Credential must have an api_key' if credential.api_key.blank?

      @credential = credential
      @client = Octokit::Client.new(access_token: credential.api_key)
      
      # Configure Octokit client options
      @client.auto_paginate = true
    end

    # Merge a pull request for a given task
    #
    # @param task [Task] The task object containing branch_name and epic/repository associations
    # @return [String] The merge commit SHA
    # @raise [ArgumentError] if task is invalid or missing required associations
    # @raise [StandardError] if PR is not found or not mergeable
    def merge_pull_request(task)
      validate_task!(task)

      repo_name = task.epic.repository.name
      branch_name = task.branch_name

      # Find the pull request by branch name
      pr = find_pull_request(repo_name, branch_name)
      raise StandardError, "Pull request not found for branch '#{branch_name}'" if pr.nil?

      # Check if PR is mergeable
      raise StandardError, "Pull request ##{pr.number} is not mergeable" unless pr.mergeable

      # Merge the pull request
      merge_result = @client.merge_pull_request(
        repo_name,
        pr.number,
        "Merge pull request ##{pr.number} from #{branch_name}"
      )

      merge_result.sha
    rescue Octokit::NotFound => e
      raise StandardError, "Pull request not found: #{e.message}"
    rescue Octokit::MethodNotAllowed => e
      raise StandardError, "Pull request cannot be merged: #{e.message}"
    rescue Octokit::Conflict => e
      raise StandardError, "Pull request has conflicts: #{e.message}"
    end

    # Delete a remote Git branch after a successful merge
    #
    # @param task [Task] The task object containing branch_name and epic/repository associations
    # @return [Boolean] true if the branch was successfully deleted
    # @raise [ArgumentError] if task is invalid or missing required associations
    # @raise [StandardError] if branch deletion fails
    def delete_branch(task)
      validate_task!(task)

      repo_name = task.epic.repository.name
      branch_name = task.branch_name

      # Delete the remote branch using the refs API
      # The ref format for branches is "heads/branch_name"
      @client.delete_ref(repo_name, "heads/#{branch_name}")
      
      true
    rescue Octokit::NotFound => e
      raise StandardError, "Branch '#{branch_name}' not found: #{e.message}"
    rescue Octokit::UnprocessableEntity => e
      raise StandardError, "Cannot delete branch '#{branch_name}': #{e.message}"
    end

    # Infer the base branch for a given repository
    #
    # This method fetches the repository's default branch (e.g., 'main', 'master')
    # from GitHub's API.
    #
    # @param repo_name [String] The repository name in format 'owner/repo'
    # @return [String] The default branch name (e.g., 'main')
    # @raise [ArgumentError] if repo_name is nil or blank
    # @raise [StandardError] if repository is not found or API request fails
    def infer_base_branch(repo_name)
      raise ArgumentError, 'Repository name cannot be nil or blank' if repo_name.blank?

      # Fetch repository information from GitHub
      repo = @client.repository(repo_name)
      
      # Return the default branch name
      repo.default_branch
    rescue Octokit::NotFound => e
      raise StandardError, "Repository '#{repo_name}' not found: #{e.message}"
    rescue Octokit::Unauthorized => e
      raise StandardError, "Authentication failed: #{e.message}"
    rescue Octokit::Forbidden => e
      raise StandardError, "Access forbidden to repository '#{repo_name}': #{e.message}"
    end

    private

    # Validate the task and its associations
    #
    # @param task [Task] The task to validate
    # @raise [ArgumentError] if task is invalid
    def validate_task!(task)
      raise ArgumentError, 'Task cannot be nil' if task.nil?
      raise ArgumentError, 'Task must have a branch_name' if task.branch_name.blank?
      raise ArgumentError, 'Task must belong to an epic' if task.epic.nil?
      raise ArgumentError, 'Epic must have a repository' if task.epic.repository.nil?
      raise ArgumentError, 'Repository must have a name' if task.epic.repository.name.blank?
    end

    # Find an open pull request by branch name
    #
    # @param repo_name [String] The repository name (e.g., 'owner/repo')
    # @param branch_name [String] The branch name to search for
    # @return [Sawyer::Resource, nil] The pull request object or nil if not found
    def find_pull_request(repo_name, branch_name)
      pull_requests = @client.pull_requests(repo_name, state: 'open')
      pull_requests.find { |pr| pr.head.ref == branch_name }
    end
  end
end
