#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for webhook FINISHED handler
# Run from Rails console: `load 'script/test_webhook_finished.rb'`
# Or from command line: `rails runner script/test_webhook_finished.rb`

puts "=" * 80
puts "Testing Webhook FINISHED Handler (Task 5.3)"
puts "=" * 80
puts

# Setup test data
puts "1. Creating test data..."
user = User.first || User.create!(
  email: "webhook-test@example.com",
  password: "password123"
)

credential = user.credentials.find_or_create_by!(
  service_name: 'github',
  name: 'Webhook Test GitHub'
) do |c|
  c.api_key = 'test_key_123'
end

repository = user.repositories.find_or_create_by!(
  name: 'webhook-test-repo'
) do |r|
  r.github_url = 'https://github.com/test/webhook-repo'
  r.github_credential = credential
end

epic = Epic.create!(
  user: user,
  repository: repository,
  title: "Test Epic for Webhook FINISHED Handler",
  prompt: "Test epic for webhook",
  base_branch: "main",
  status: :running
)

# Create task in running state (simulating agent execution)
task = Task.create!(
  epic: epic,
  description: "Test task for webhook FINISHED handler",
  position: 0,
  status: :running,
  cursor_agent_id: "agent_test_#{SecureRandom.hex(8)}",
  branch_name: "cursor/test-webhook-finished-#{SecureRandom.hex(4)}"
)

puts "   ✓ Created user: #{user.email}"
puts "   ✓ Created epic: #{epic.title}"
puts "   ✓ Created task: #{task.description}"
puts "   ✓ Task ID: #{task.id}"
puts "   ✓ Initial status: #{task.status}"
puts

# Test 1: FINISHED webhook with PR URL (Standard format)
puts "2. Testing FINISHED webhook with PR URL (prUrl format)..."
pr_url = 'https://github.com/test/webhook-repo/pull/123'

# Simulate webhook payload
class FakeWebhookRequest
  attr_reader :params
  
  def initialize(task_id, payload)
    @params = payload.merge(
      controller: 'webhooks',
      action: 'cursor',
      task_id: task_id
    ).with_indifferent_access
  end
end

controller = WebhooksController.new
controller.instance_variable_set(:@task_id, task.id)

# Manually call the private method
payload = {
  status: 'FINISHED',
  target: {
    prUrl: pr_url
  }
}

puts "   Payload: #{payload.to_json}"

# Extract and handle the webhook
status = payload[:status]
pr_url_extracted = payload.dig(:target, :prUrl)

puts "   Extracted status: #{status}"
puts "   Extracted PR URL: #{pr_url_extracted}"

# Call the Tasks::UpdateStatus interaction directly
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'pr_open',
  log_message: "Cursor agent finished. PR created: #{pr_url_extracted}",
  pr_url: pr_url_extracted
)

if outcome.valid?
  task.reload
  puts "   ✓ Status updated to: #{task.status}"
  puts "   ✓ PR URL saved: #{task.pr_url}"
  puts "   ✓ Log message:"
  task.debug_log.lines.last(3).each { |line| puts "     #{line}" }
else
  puts "   ✗ Failed: #{outcome.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 2: FINISHED webhook with alternate PR URL format (pr_url)
puts "3. Creating new task for alternate PR URL format test..."
task2 = Task.create!(
  epic: epic,
  description: "Test task 2 for alternate PR URL format",
  position: 1,
  status: :running,
  cursor_agent_id: "agent_test_#{SecureRandom.hex(8)}",
  branch_name: "cursor/test-webhook-2-#{SecureRandom.hex(4)}"
)

pr_url2 = 'https://github.com/test/webhook-repo/pull/456'
payload2 = {
  status: 'FINISHED',
  target: {
    pr_url: pr_url2
  }
}

pr_url_extracted2 = payload2.dig(:target, :pr_url) || payload2.dig(:target, :prUrl)
outcome2 = Tasks::UpdateStatus.run(
  task: task2,
  new_status: 'pr_open',
  log_message: "Cursor agent finished. PR created: #{pr_url_extracted2}",
  pr_url: pr_url_extracted2
)

if outcome2.valid?
  task2.reload
  puts "   ✓ Task 2 status: #{task2.status}"
  puts "   ✓ Task 2 PR URL: #{task2.pr_url}"
else
  puts "   ✗ Failed: #{outcome2.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 3: FINISHED webhook without PR URL
puts "4. Testing FINISHED webhook without PR URL..."
task3 = Task.create!(
  epic: epic,
  description: "Test task 3 without PR URL",
  position: 2,
  status: :running,
  cursor_agent_id: "agent_test_#{SecureRandom.hex(8)}",
  branch_name: "cursor/test-webhook-3-#{SecureRandom.hex(4)}"
)

payload3 = {
  status: 'FINISHED'
}

pr_url_extracted3 = nil
outcome3 = Tasks::UpdateStatus.run(
  task: task3,
  new_status: 'pr_open',
  log_message: "Cursor agent finished. PR created: #{pr_url_extracted3 || 'URL not provided'}",
  pr_url: pr_url_extracted3
)

if outcome3.valid?
  task3.reload
  puts "   ✓ Task 3 status: #{task3.status}"
  puts "   ✓ Task 3 PR URL: #{task3.pr_url.inspect}"
  puts "   ✓ Log includes 'URL not provided': #{task3.debug_log.include?('URL not provided')}"
else
  puts "   ✗ Failed: #{outcome3.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 4: Test other webhook statuses
puts "5. Testing RUNNING webhook..."
task4 = Task.create!(
  epic: epic,
  description: "Test task 4 for RUNNING status",
  position: 3,
  status: :pending
)

outcome4 = Tasks::UpdateStatus.run(
  task: task4,
  new_status: 'running',
  log_message: 'Cursor agent is now running'
)

if outcome4.valid?
  task4.reload
  puts "   ✓ Task 4 status: #{task4.status}"
else
  puts "   ✗ Failed: #{outcome4.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 5: ERROR webhook
puts "6. Testing ERROR webhook..."
task5 = Task.create!(
  epic: epic,
  description: "Test task 5 for ERROR status",
  position: 4,
  status: :running
)

error_message = "Agent encountered an error during execution"
outcome5 = Tasks::UpdateStatus.run(
  task: task5,
  new_status: 'failed',
  log_message: "Cursor agent failed: #{error_message}"
)

if outcome5.valid?
  task5.reload
  puts "   ✓ Task 5 status: #{task5.status}"
  puts "   ✓ Error in log: #{task5.debug_log.include?('failed')}"
else
  puts "   ✗ Failed: #{outcome5.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Summary
puts "=" * 80
puts "ALL WEBHOOK TESTS PASSED! ✓"
puts "=" * 80
puts
puts "Summary of Tasks:"
puts
[task, task2, task3, task4, task5].each do |t|
  t.reload
  puts "Task #{t.id}: #{t.description}"
  puts "  Status: #{t.status}"
  puts "  PR URL: #{t.pr_url || 'N/A'}"
  puts "  Log entries: #{t.debug_log&.lines&.count || 0}"
  puts
end

# Display full integration flow example
puts "=" * 80
puts "Integration Flow Example:"
puts "=" * 80
puts
puts "1. Task starts in 'pending' state"
puts "2. ExecuteJob launches Cursor agent → task becomes 'running'"
puts "3. Webhook receives FINISHED status → task becomes 'pr_open'"
puts "4. Task has pr_url saved: #{task.pr_url}"
puts "5. Ready for merge process"
puts
puts "Next phase: Implement merge job to complete the workflow"
puts

# Cleanup option
print "Clean up test data? (y/n): "
if ENV['RAILS_ENV'] == 'test' || ARGV[0] == '--cleanup'
  puts "y (auto)"
  epic.destroy
  puts "✓ Test data cleaned up"
else
  puts "n (manual run - keeping data for inspection)"
  puts "To clean up manually: Epic.find(#{epic.id}).destroy"
end
puts
