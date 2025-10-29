#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for webhook controller
# This script sends test webhook payloads to the local server

require 'net/http'
require 'json'
require 'uri'

# Configuration
BASE_URL = ENV.fetch('WEBHOOK_BASE_URL', 'http://localhost:3000')
TASK_ID = ENV.fetch('TEST_TASK_ID', '1')

def send_webhook(task_id, payload)
  uri = URI.parse("#{BASE_URL}/webhooks/cursor/#{task_id}")
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  
  request = Net::HTTP::Post.new(uri.path)
  request['Content-Type'] = 'application/json'
  request.body = payload.to_json
  
  puts "\n" + "=" * 80
  puts "Sending webhook to: #{uri}"
  puts "-" * 80
  puts "Payload:"
  puts JSON.pretty_generate(payload)
  puts "=" * 80
  
  response = http.request(request)
  
  puts "Response Status: #{response.code} #{response.message}"
  puts "Response Body:"
  puts JSON.pretty_generate(JSON.parse(response.body))
  puts "=" * 80
  
  response
rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.join("\n")
end

# Test payloads for different statuses
def test_running_status(task_id)
  puts "\n### Testing RUNNING status ###"
  payload = {
    status: 'RUNNING',
    agent_id: 'bc_test_123',
    timestamp: Time.now.iso8601,
    message: 'Agent started processing task'
  }
  send_webhook(task_id, payload)
end

def test_finished_status(task_id)
  puts "\n### Testing FINISHED status ###"
  payload = {
    status: 'FINISHED',
    agent_id: 'bc_test_123',
    timestamp: Time.now.iso8601,
    target: {
      prUrl: 'https://github.com/test/repo/pull/123',
      branch: 'cursor-agent/task-1-test'
    },
    message: 'Agent completed successfully'
  }
  send_webhook(task_id, payload)
end

def test_error_status(task_id)
  puts "\n### Testing ERROR status ###"
  payload = {
    status: 'ERROR',
    agent_id: 'bc_test_123',
    timestamp: Time.now.iso8601,
    error: {
      code: 'EXECUTION_FAILED',
      message: 'Failed to execute task'
    },
    message: 'Agent encountered an error'
  }
  send_webhook(task_id, payload)
end

def test_invalid_task
  puts "\n### Testing Invalid Task ID ###"
  payload = {
    status: 'RUNNING',
    agent_id: 'bc_test_123',
    timestamp: Time.now.iso8601
  }
  send_webhook(99999, payload)
end

def test_invalid_payload(task_id)
  puts "\n### Testing Invalid Payload (no status) ###"
  payload = {
    agent_id: 'bc_test_123',
    timestamp: Time.now.iso8601
  }
  send_webhook(task_id, payload)
end

# Main execution
if __FILE__ == $0
  puts "=" * 80
  puts "Webhook Testing Script"
  puts "=" * 80
  puts "Base URL: #{BASE_URL}"
  puts "Task ID: #{TASK_ID}"
  puts "=" * 80
  
  # Check if task exists
  puts "\nNote: Make sure task #{TASK_ID} exists in the database"
  puts "You can create one in rails console:"
  puts "  user = User.first || User.create!(email: 'test@test.com', password: 'password')"
  puts "  repo = Repository.create!(name: 'test-repo', github_url: 'https://github.com/test/repo', user: user)"
  puts "  epic = Epic.create!(title: 'Test Epic', repository: repo, user: user, base_branch: 'main')"
  puts "  task = Task.create!(epic: epic, description: 'Test task', position: 1)"
  puts "\nPress Enter to continue or Ctrl+C to abort..."
  gets
  
  # Run tests
  test_running_status(TASK_ID)
  sleep 1
  
  test_finished_status(TASK_ID)
  sleep 1
  
  test_error_status(TASK_ID)
  sleep 1
  
  test_invalid_task
  sleep 1
  
  test_invalid_payload(TASK_ID)
  
  puts "\n" + "=" * 80
  puts "Testing Complete!"
  puts "Check log/development.log for detailed webhook logs"
  puts "=" * 80
end
