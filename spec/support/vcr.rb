# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  # Directory where VCR cassettes will be stored
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  
  # Use WebMock as the HTTP stubbing library
  config.hook_into :webmock
  
  # Default cassette options
  config.default_cassette_options = {
    record: :once, # Record new interactions once, then replay
    match_requests_on: [:method, :uri, :body]
  }
  
  # Filter sensitive data - replace real tokens with placeholder
  config.filter_sensitive_data('<GITHUB_TOKEN>') { ENV['GITHUB_TOKEN'] }
  config.filter_sensitive_data('<GITHUB_TOKEN>') do |interaction|
    # Also filter Authorization headers
    auth_header = interaction.request.headers['Authorization']&.first
    if auth_header && auth_header.start_with?('token ', 'Bearer ')
      auth_header.split(' ', 2).last
    end
  end
  
  # Configure VCR to work with RSpec metadata
  # This allows using `it 'test', :vcr do` syntax
  config.configure_rspec_metadata!
  
  # Allow connections to localhost (for local development)
  config.ignore_localhost = true
  
  # Preserve exact body match for GitHub API responses
  config.preserve_exact_body_bytes { |http_message| !http_message.body.empty? }
end
