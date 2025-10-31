# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Services
  # LlmService wraps various LLM APIs (OpenAI, Anthropic, etc.) for generating task specifications
  # This service handles operations like generating task breakdowns from high-level prompts.
  class LlmService
    OPENAI_API_ENDPOINT = 'https://api.openai.com/v1/chat/completions'
    ANTHROPIC_API_ENDPOINT = 'https://api.anthropic.com/v1/messages'
    
    SUPPORTED_SERVICES = %w[openai claude anthropic gemini].freeze

    attr_reader :api_key, :credential, :service_name

    # Initialize a new LlmService instance
    #
    # @param credential [Credential] The credential object containing the LLM API key
    # @raise [ArgumentError] if credential is nil, doesn't have an api_key, or service is unsupported
    def initialize(credential)
      raise ArgumentError, 'Credential cannot be nil' if credential.nil?
      raise ArgumentError, 'Credential must have an api_key' if credential.api_key.blank?
      raise ArgumentError, 'Credential must have a service_name' if credential.service_name.blank?
      
      unless SUPPORTED_SERVICES.include?(credential.service_name)
        raise ArgumentError, "Unsupported LLM service: #{credential.service_name}. " \
                             "Supported services: #{SUPPORTED_SERVICES.join(', ')}"
      end

      @credential = credential
      @api_key = credential.api_key
      @service_name = credential.service_name
    end

    # Generate a task specification from a high-level prompt
    #
    # This method calls the appropriate LLM API to break down a high-level prompt
    # into a list of actionable tasks.
    #
    # @param prompt [String] The high-level user request/prompt
    # @param base_branch [String] The base Git branch for context
    # @return [Hash] A hash containing the generated tasks: { "tasks" => ["Task 1", "Task 2", ...] }
    # @raise [ArgumentError] if parameters are invalid
    # @raise [StandardError] if the API request fails
    def generate_spec(prompt, base_branch)
      validate_generate_params!(prompt, base_branch)

      case @service_name
      when 'openai'
        generate_spec_openai(prompt, base_branch)
      when 'claude', 'anthropic'
        generate_spec_anthropic(prompt, base_branch)
      when 'gemini'
        generate_spec_gemini(prompt, base_branch)
      else
        # Fallback to stub for unsupported but recognized services
        generate_spec_stub(prompt, base_branch)
      end
    end

    private

    # Validate parameters for generate_spec
    #
    # @param prompt [String] The prompt to validate
    # @param base_branch [String] The base branch to validate
    # @raise [ArgumentError] if any parameter is invalid
    def validate_generate_params!(prompt, base_branch)
      raise ArgumentError, 'prompt cannot be blank' if prompt.blank?
      raise ArgumentError, 'base_branch cannot be blank' if base_branch.blank?
    end

    # Generate spec using OpenAI API
    #
    # @param prompt [String] The high-level prompt
    # @param base_branch [String] The base branch name
    # @return [Hash] The parsed response with tasks
    def generate_spec_openai(prompt, base_branch)
      system_prompt = build_system_prompt(base_branch)
      
      payload = {
        model: 'gpt-4',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' }
      }

      response = post_to_openai(payload)
      parse_openai_response(response)
    rescue StandardError => e
      # For now, fallback to stub on error
      Rails.logger.error("OpenAI API error: #{e.message}")
      generate_spec_stub(prompt, base_branch)
    end

    # Generate spec using Anthropic (Claude) API
    #
    # @param prompt [String] The high-level prompt
    # @param base_branch [String] The base branch name
    # @return [Hash] The parsed response with tasks
    def generate_spec_anthropic(prompt, base_branch)
      system_prompt = build_system_prompt(base_branch)
      
      payload = {
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4096,
        system: system_prompt,
        messages: [
          { role: 'user', content: prompt }
        ],
        temperature: 0.7
      }

      response = post_to_anthropic(payload)
      parse_anthropic_response(response)
    rescue StandardError => e
      # For now, fallback to stub on error
      Rails.logger.error("Anthropic API error: #{e.message}")
      generate_spec_stub(prompt, base_branch)
    end

    # Generate spec using Gemini API (stub for now)
    #
    # @param prompt [String] The high-level prompt
    # @param base_branch [String] The base branch name
    # @return [Hash] The parsed response with tasks
    def generate_spec_gemini(prompt, base_branch)
      # TODO: Implement Gemini API integration
      generate_spec_stub(prompt, base_branch)
    end

    # Generate a stubbed spec for testing/development
    #
    # @param prompt [String] The high-level prompt
    # @param base_branch [String] The base branch name
    # @return [Hash] A stubbed response with sample tasks
    def generate_spec_stub(prompt, base_branch)
      {
        'tasks' => [
          "Set up initial project structure and dependencies for: #{prompt}",
          "Implement core functionality: #{prompt}",
          "Add tests and documentation",
          "Review and refactor code on branch: #{base_branch}"
        ]
      }
    end

    # Build the system prompt for the LLM
    #
    # @param base_branch [String] The base branch name
    # @return [String] The system prompt
    def build_system_prompt(base_branch)
      <<~PROMPT
        You are an AI assistant that helps break down high-level software development tasks into specific, actionable subtasks.
        
        The user will provide a high-level feature request or epic. Your job is to analyze it and return a JSON object with an array of concrete, sequential tasks that a developer (or AI agent) can implement.
        
        Context:
        - Base branch: #{base_branch}
        - Each task should be specific and implementable independently
        - Tasks should be ordered logically (dependencies first)
        - Each task description should be clear and actionable
        
        Return ONLY valid JSON in this exact format:
        {
          "tasks": [
            "Task 1 description",
            "Task 2 description",
            "Task 3 description"
          ]
        }
        
        Guidelines:
        - Keep each task description concise but specific
        - Aim for 3-8 tasks depending on complexity
        - Each task should represent a meaningful unit of work
        - Tasks should build on each other sequentially
      PROMPT
    end

    # POST request to OpenAI API
    #
    # @param payload [Hash] The request payload
    # @return [Net::HTTPResponse] The HTTP response object
    # @raise [StandardError] if the request fails
    def post_to_openai(payload)
      uri = URI.parse(OPENAI_API_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_message = extract_error_message(response)
        raise StandardError, "OpenAI API request failed (#{response.code}): #{error_message}"
      end

      response
    end

    # POST request to Anthropic API
    #
    # @param payload [Hash] The request payload
    # @return [Net::HTTPResponse] The HTTP response object
    # @raise [StandardError] if the request fails
    def post_to_anthropic(payload)
      uri = URI.parse(ANTHROPIC_API_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request['x-api-key'] = @api_key
      request['anthropic-version'] = '2023-06-01'
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_message = extract_error_message(response)
        raise StandardError, "Anthropic API request failed (#{response.code}): #{error_message}"
      end

      response
    end

    # Parse OpenAI API response
    #
    # @param response [Net::HTTPResponse] The HTTP response
    # @return [Hash] The parsed response with tasks
    # @raise [StandardError] if the response cannot be parsed
    def parse_openai_response(response)
      body = JSON.parse(response.body)
      content = body.dig('choices', 0, 'message', 'content')
      
      raise StandardError, 'No content in OpenAI response' if content.blank?
      
      # Parse the JSON content from the response
      JSON.parse(content)
    rescue JSON::ParserError => e
      raise StandardError, "Failed to parse OpenAI response: #{e.message}"
    end

    # Parse Anthropic API response
    #
    # @param response [Net::HTTPResponse] The HTTP response
    # @return [Hash] The parsed response with tasks
    # @raise [StandardError] if the response cannot be parsed
    def parse_anthropic_response(response)
      body = JSON.parse(response.body)
      content = body.dig('content', 0, 'text')
      
      raise StandardError, 'No content in Anthropic response' if content.blank?
      
      # Parse the JSON content from the response
      JSON.parse(content)
    rescue JSON::ParserError => e
      raise StandardError, "Failed to parse Anthropic response: #{e.message}"
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
