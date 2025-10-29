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
  end
end
