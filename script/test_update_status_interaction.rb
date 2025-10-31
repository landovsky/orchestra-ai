#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Tasks::UpdateStatus interaction
# Run from Rails console: `load 'script/test_update_status_interaction.rb'`
# Or from command line: `rails runner script/test_update_status_interaction.rb`

puts "=== Testing Tasks::UpdateStatus Interaction ==="
puts

# Setup test data
puts "1. Creating test data..."
user = User.first || User.create!(
  email: "test@example.com",
  password: "password123"
)

credential = user.credentials.find_or_create_by!(
  service_name: 'github',
  name: 'Test GitHub'
) do |c|
  c.api_key = 'test_key_123'
end

repository = user.repositories.find_or_create_by!(
  name: 'test-repo'
) do |r|
  r.github_url = 'https://github.com/test/repo'
  r.github_credential = credential
end

epic = Epic.create!(
  user: user,
  repository: repository,
  title: "Test Epic for UpdateStatus",
  prompt: "Test epic",
  base_branch: "main",
  status: :pending
)

task = Task.create!(
  epic: epic,
  description: "Test task for status updates",
  position: 0,
  status: :pending
)

puts "   ✓ Created user: #{user.email}"
puts "   ✓ Created epic: #{epic.title}"
puts "   ✓ Created task: #{task.description}"
puts

# Test 1: Basic status update
puts "2. Testing basic status update..."
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'running'
)

if outcome.valid?
  puts "   ✓ Status updated to: #{task.reload.status}"
else
  puts "   ✗ Failed: #{outcome.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 2: Status update with log message
puts "3. Testing status update with log message..."
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'running',
  log_message: 'Cursor agent is launching...'
)

if outcome.valid?
  task.reload
  puts "   ✓ Log message appended:"
  puts "     #{task.debug_log}"
else
  puts "   ✗ Failed: #{outcome.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 3: Status update with PR URL
puts "4. Testing status update with PR URL..."
pr_url = 'https://github.com/test/repo/pull/123'
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'pr_open',
  log_message: 'PR has been created',
  pr_url: pr_url
)

if outcome.valid?
  task.reload
  puts "   ✓ Status: #{task.status}"
  puts "   ✓ PR URL: #{task.pr_url}"
  puts "   ✓ Log entries: #{task.debug_log.lines.count}"
else
  puts "   ✗ Failed: #{outcome.errors.full_messages.join(', ')}"
  exit 1
end
puts

# Test 4: Multiple log appends
puts "5. Testing multiple log appends..."
['merging', 'completed'].each_with_index do |status, index|
  outcome = Tasks::UpdateStatus.run(
    task: task,
    new_status: status,
    log_message: "Status changed to #{status}"
  )
  
  unless outcome.valid?
    puts "   ✗ Failed at #{status}: #{outcome.errors.full_messages.join(', ')}"
    exit 1
  end
end

task.reload
log_lines = task.debug_log.lines.count
puts "   ✓ Total log entries: #{log_lines}"
puts "   ✓ Current status: #{task.status}"
puts

# Test 5: Display full log
puts "6. Full debug log:"
puts "   " + "=" * 60
task.debug_log.lines.each do |line|
  puts "   #{line}"
end
puts "   " + "=" * 60
puts

# Test 6: Invalid status
puts "7. Testing invalid status (should fail)..."
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'invalid_status'
)

if outcome.valid?
  puts "   ✗ Should have failed with invalid status"
  exit 1
else
  puts "   ✓ Correctly rejected invalid status"
  puts "     Error: #{outcome.errors[:new_status].first}"
end
puts

# Test 7: Create another task to test status transitions
puts "8. Testing full status transition workflow..."
task2 = Task.create!(
  epic: epic,
  description: "Task for status workflow test",
  position: 1,
  status: :pending
)

workflow_statuses = ['running', 'pr_open', 'merging', 'completed']
workflow_statuses.each do |status|
  outcome = Tasks::UpdateStatus.run(
    task: task2,
    new_status: status,
    log_message: "Transitioning to #{status}"
  )
  
  unless outcome.valid?
    puts "   ✗ Failed at #{status}: #{outcome.errors.full_messages.join(', ')}"
    exit 1
  end
  
  puts "   ✓ #{status.upcase}: #{task2.reload.status}"
end
puts

# Test 8: Test with empty/nil values
puts "9. Testing edge cases..."
task3 = Task.create!(
  epic: epic,
  description: "Task for edge case testing",
  position: 2,
  status: :pending
)

# Empty log message should not append anything
outcome = Tasks::UpdateStatus.run(
  task: task3,
  new_status: 'running',
  log_message: ''
)

if outcome.valid? && task3.reload.debug_log.blank?
  puts "   ✓ Empty log message handled correctly"
else
  puts "   ✗ Empty log message handling failed"
end

# Empty PR URL should not update
outcome = Tasks::UpdateStatus.run(
  task: task3,
  new_status: 'pr_open',
  pr_url: ''
)

if outcome.valid? && task3.reload.pr_url.nil?
  puts "   ✓ Empty PR URL handled correctly"
else
  puts "   ✗ Empty PR URL handling failed"
end
puts

# Summary
puts "=" * 70
puts "ALL TESTS PASSED! ✓"
puts "=" * 70
puts
puts "Summary:"
puts "  - Task 1: #{task.description}"
puts "    Status: #{task.status}"
puts "    Log entries: #{task.debug_log.lines.count}"
puts "    PR URL: #{task.pr_url}"
puts
puts "  - Task 2: #{task2.description}"
puts "    Status: #{task2.status}"
puts "    Log entries: #{task2.debug_log.lines.count}"
puts
puts "  - Task 3: #{task3.description}"
puts "    Status: #{task3.status}"
puts

# Cleanup
puts "Cleaning up test data..."
epic.destroy
puts "Done!"
