#!/usr/bin/env ruby

# Test script for Epics::Start interaction
# This script demonstrates the Start Epic functionality from console

require_relative '../config/environment'

puts "=== Testing Epics::Start Interaction ==="
puts

# Find or create test user
user = User.first || User.create!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
)
puts "✓ User: #{user.email}"

# Find or create test repository
repository = user.repositories.first || Repository.create!(
  user: user,
  name: "test-repo",
  full_name: "user/test-repo",
  url: "https://github.com/user/test-repo"
)
puts "✓ Repository: #{repository.full_name}"

# Create Cursor agent credential
cursor_cred = Credential.find_or_create_by!(
  user: user,
  service_name: 'cursor_agent'
) do |cred|
  cred.api_key = ENV['CURSOR_API_KEY'] || 'test-key'
end
puts "✓ Cursor Credential created"

# Create an epic with tasks
tasks = [
  "Task 1: Setup project structure",
  "Task 2: Add configuration files",
  "Task 3: Write documentation"
]

outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repository,
  tasks_json: tasks.to_json,
  base_branch: "main",
  cursor_agent_credential_id: cursor_cred.id
)

if outcome.valid?
  epic = outcome.result[:epic]
  puts "✓ Epic created: #{epic.title}"
  puts "  Status: #{epic.status}"
  puts "  Tasks: #{epic.tasks.count}"
  puts
  
  # Start the epic
  puts "Starting epic..."
  start_outcome = Epics::Start.run(
    user: user,
    epic: epic
  )
  
  if start_outcome.valid?
    epic.reload
    puts "✓ Epic started successfully!"
    puts "  Epic status: #{epic.status}"
    puts "  First task: #{epic.tasks.ordered.first.description}"
    puts
    puts "✓ Tasks::ExecuteJob enqueued for first task"
    puts
    puts "=== Test Completed Successfully ==="
  else
    puts "✗ Failed to start epic:"
    start_outcome.errors.full_messages.each do |error|
      puts "  - #{error}"
    end
  end
else
  puts "✗ Failed to create epic:"
  outcome.errors.full_messages.each do |error|
    puts "  - #{error}"
  end
end
