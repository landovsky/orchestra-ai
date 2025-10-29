# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Services
  # CursorAgentService wraps the Cursor API for launching AI agents
  # This service handles operations like launching agents with specific tasks and configurations.
  class CursorAgentService
    CURSOR_API_ENDPOINT = 'https://api.cursor.com/v0/agents'
    WEBHOOK_SECRET = ENV.fetch('CURSOR_WEBHOOK_SECRET', 'default-webhook-secret')

    attr_reader :api_key, :credential

    # Initialize a new CursorAgentService instance
    #
    # @param credential [Credential] The credential object containing the Cursor API key
    # @raise [ArgumentError] if credential is nil or doesn't have an api_key
    def initialize(credential)
      raise ArgumentError, 'Credential cannot be nil' if credential.nil?
      raise ArgumentError, 'Credential must have an api_key' if credential.api_key.blank?

      @credential = credential
      @api_key = credential.api_key
    end

    # Launch a Cursor agent for a given task
    #
    # This method creates a new agent instance via the Cursor API with the appropriate
    # configuration including source repository, target branch, and webhook callback.
    #
    # @param task [Task] The task object containing description and epic/repository associations
    # @param webhook_url [String] The webhook URL where Cursor will send status updates
    # @param branch_name [String] The Git branch name where the agent will create changes
    # @return [Hash] The parsed API response containing the agent ID and other metadata
    # @raise [ArgumentError] if any parameters are invalid
    # @raise [StandardError] if the API request fails
    def launch_agent(task:, webhook_url:, branch_name:)
      validate_launch_params!(task, webhook_url, branch_name)

      payload = build_payload(task, webhook_url, branch_name)
      response = post_to_cursor_api(payload)

      parse_response(response)
    end

    private

    # Validate parameters for launch_agent
    #
    # @param task [Task] The task to validate
    # @param webhook_url [String] The webhook URL to validate
    # @param branch_name [String] The branch name to validate
    # @raise [ArgumentError] if any parameter is invalid
    def validate_launch_params!(task, webhook_url, branch_name)
      raise ArgumentError, 'Task cannot be nil' if task.nil?
      raise ArgumentError, 'Task must have a description' if task.description.blank?
      raise ArgumentError, 'Task must belong to an epic' if task.epic.nil?
      raise ArgumentError, 'Epic must have a repository' if task.epic.repository.nil?
      raise ArgumentError, 'Repository must have a github_url' if task.epic.repository.github_url.blank?
      raise ArgumentError, 'Epic must have a base_branch' if task.epic.base_branch.blank?
      raise ArgumentError, 'webhook_url cannot be blank' if webhook_url.blank?
      raise ArgumentError, 'branch_name cannot be blank' if branch_name.blank?
    end

    # Build the JSON payload for the Cursor API
    #
    # @param task [Task] The task containing the prompt and context
    # @param webhook_url [String] The webhook URL for callbacks
    # @param branch_name [String] The target branch name
    # @return [Hash] The payload hash to be sent to the API
    def build_payload(task, webhook_url, branch_name)
      {
        prompt: {
          text: task.description
        },
        source: {
          repository: task.epic.repository.github_url,
          ref: task.epic.base_branch
        },
        target: {
          branchName: branch_name,
          autoCreatePr: true
        },
        webhook: {
          url: webhook_url,
          secret: WEBHOOK_SECRET
        }
      }
    end

    # POST the payload to the Cursor API
    #
    # @param payload [Hash] The request payload
    # @return [Net::HTTPResponse] The HTTP response object
    # @raise [StandardError] if the request fails
    def post_to_cursor_api(payload)
      uri = URI.parse(CURSOR_API_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_message = extract_error_message(response)
        raise StandardError, "Cursor API request failed (#{response.code}): #{error_message}"
      end

      response
    rescue StandardError => e
      raise StandardError, "Failed to communicate with Cursor API: #{e.message}"
    end

    # Parse the API response
    #
    # @param response [Net::HTTPResponse] The HTTP response
    # @return [Hash] The parsed JSON response
    # @raise [StandardError] if the response cannot be parsed
    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise StandardError, "Failed to parse Cursor API response: #{e.message}"
    end

    # Extract error message from response
    #
    # @param response [Net::HTTPResponse] The HTTP response
    # @return [String] The error message
    def extract_error_message(response)
      body = JSON.parse(response.body)
      body['error'] || body['message'] || response.body
    rescue JSON::ParserError
      response.body
    end
  end
end
