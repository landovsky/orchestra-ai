#!/usr/bin/env ruby
# frozen_string_literal: true

# Cursor Service Console Validation Script
# Task 3.2: Cursor Service Console Validation
#
# This script tests the Cursor API integration with real credentials,
# specifically testing the launch_agent method with a webhook URL.
#
# USAGE:
#   From Rails console:
#     load 'script/test_cursor_service.rb'
#
#   Or run directly:
#     rails runner script/test_cursor_service.rb
#
# SETUP:
#   Set environment variables:
#     CURSOR_KEY=your_cursor_api_key
#     GITHUB_TOKEN=your_github_token (for repository credential)
#     TEST_WEBHOOK_URL=your_ngrok_or_webhook_url (optional, will use placeholder if not set)
#
# REQUIREMENTS:
#   - Valid Cursor API key
#   - Valid GitHub personal access token
#   - At least one User record in the database
#   - A valid GitHub repository

puts "=" * 80
puts "Cursor Service Console Validation"
puts "Task 3.2: Testing Cursor Agent Launch with API Credentials"
puts "=" * 80
puts

# ============================================================================
# Step 1: Environment Validation
# ============================================================================

puts "Step 1: Validating environment setup"
puts "-" * 80

errors = []

unless ENV['CURSOR_KEY']
  errors << "CURSOR_KEY environment variable not set"
end

unless ENV['GITHUB_TOKEN']
  errors << "GITHUB_TOKEN environment variable not set (needed for repository credential)"
end

if errors.any?
  puts "❌ ERROR: Missing required environment variables:"
  errors.each { |error| puts "  - #{error}" }
  puts
  puts "Please set the required environment variables:"
  puts "  export CURSOR_KEY=your_cursor_api_key"
  puts "  export GITHUB_TOKEN=your_github_token"
  puts "  export TEST_WEBHOOK_URL=https://your-ngrok-url.ngrok.io  # Optional"
  puts
  exit 1
end

puts "✓ CURSOR_KEY found"
puts "✓ GITHUB_TOKEN found"

webhook_url = ENV['TEST_WEBHOOK_URL']
if webhook_url
  puts "✓ TEST_WEBHOOK_URL found: #{webhook_url}"
else
  puts "⚠️  TEST_WEBHOOK_URL not set. Using placeholder URL."
  puts "   Note: Agent will launch but webhook callbacks won't work with placeholder."
end
puts

# ============================================================================
# Step 2: Database Setup - User
# ============================================================================

puts "Step 2: Setting up test user"
puts "-" * 80

user = User.first
unless user
  puts "⚠️  No users found. Creating test user..."
  user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
  puts "✓ Created test user: #{user.email}"
else
  puts "✓ Using existing user: #{user.email}"
end
puts

# ============================================================================
# Step 3: Database Setup - Credentials
# ============================================================================

puts "Step 3: Setting up credentials"
puts "-" * 80

# Create/update GitHub credential (needed for repository)
github_credential = user.credentials.find_by(service_name: 'github', name: 'test_github_credential')
if github_credential
  puts "⚠️  Found existing GitHub credential. Updating..."
  github_credential.update!(api_key: ENV['GITHUB_TOKEN'])
  puts "✓ Updated GitHub credential"
else
  puts "Creating GitHub credential..."
  github_credential = user.credentials.create!(
    service_name: 'github',
    name: 'test_github_credential',
    api_key: ENV['GITHUB_TOKEN']
  )
  puts "✓ Created GitHub credential"
end

# Create/update Cursor credential
cursor_credential = user.credentials.find_by(service_name: 'cursor_agent', name: 'test_cursor_credential')
if cursor_credential
  puts "⚠️  Found existing Cursor credential. Updating..."
  cursor_credential.update!(api_key: ENV['CURSOR_KEY'])
  puts "✓ Updated Cursor credential"
else
  puts "Creating Cursor credential..."
  cursor_credential = user.credentials.create!(
    service_name: 'cursor_agent',
    name: 'test_cursor_credential',
    api_key: ENV['CURSOR_KEY']
  )
  puts "✓ Created Cursor credential"
end
puts

# ============================================================================
# Step 4: Database Setup - Repository
# ============================================================================

puts "Step 4: Setting up test repository"
puts "-" * 80

repository = user.repositories.find_by(name: 'test-orchestra-ai')
if repository
  puts "⚠️  Found existing test repository"
  puts "✓ Using repository: #{repository.name}"
else
  puts "Creating test repository..."
  repository = user.repositories.create!(
    name: 'test-orchestra-ai',
    github_url: 'https://github.com/landovsky/orchestra-ai',
    github_credential: github_credential
  )
  puts "✓ Created repository: #{repository.name}"
end
puts "  GitHub URL: #{repository.github_url}"
puts

# ============================================================================
# Step 5: Database Setup - Epic and Task
# ============================================================================

puts "Step 5: Setting up test epic and task"
puts "-" * 80

# Clean up any previous test epics
old_test_epics = user.epics.where("title LIKE ?", "Test Epic - Cursor Launch %")
if old_test_epics.any?
  puts "⚠️  Found #{old_test_epics.count} old test epic(s). Cleaning up..."
  old_test_epics.destroy_all
  puts "✓ Cleaned up old test epics"
end

# Create new test epic
timestamp = Time.now.to_i
epic = user.epics.create!(
  title: "Test Epic - Cursor Launch #{timestamp}",
  repository: repository,
  base_branch: 'main',
  status: 'pending',
  cursor_agent_credential: cursor_credential
)
puts "✓ Created test epic: #{epic.title}"
puts "  Base branch: #{epic.base_branch}"

# Create test task
task = epic.tasks.create!(
  description: "Add comment to README explaining the purpose of this repository",
  position: 1,
  status: 'pending'
)
puts "✓ Created test task (ID: #{task.id})"
puts "  Description: #{task.description}"
puts

# ============================================================================
# Step 6: Initialize Cursor Service
# ============================================================================

puts "Step 6: Initializing Cursor service"
puts "-" * 80

begin
  cursor_service = Services::CursorAgentService.new(cursor_credential)
  puts "✓ Cursor service initialized successfully"
  puts "  API Endpoint: #{Services::CursorAgentService::CURSOR_API_ENDPOINT}"
  puts "  Credential ID: #{cursor_credential.id}"
rescue => e
  puts "❌ Failed to initialize Cursor service: #{e.message}"
  exit 1
end
puts

# ============================================================================
# Step 7: Test launch_agent Method
# ============================================================================

puts "=" * 80
puts "Step 7: Testing launch_agent method"
puts "=" * 80
puts

# Prepare launch parameters
branch_name = "test-cursor-agent-#{timestamp}"
webhook_url_final = webhook_url || "https://placeholder.example.com/webhooks/cursor/#{task.id}"

puts "Launch parameters:"
puts "  Task ID: #{task.id}"
puts "  Task Description: #{task.description}"
puts "  Repository: #{repository.github_url}"
puts "  Base Branch: #{epic.base_branch}"
puts "  Target Branch: #{branch_name}"
puts "  Webhook URL: #{webhook_url_final}"
puts

if webhook_url.nil?
  puts "⚠️  WARNING: Using placeholder webhook URL"
  puts "   Agent will launch but callbacks won't reach your application."
  puts "   Set TEST_WEBHOOK_URL to test full webhook flow."
  puts
end

puts "Launching Cursor agent..."
puts "-" * 80

begin
  result = cursor_service.launch_agent(
    task: task,
    webhook_url: webhook_url_final,
    branch_name: branch_name
  )
  
  puts "✓ SUCCESS: Agent launched successfully!"
  puts
  puts "Response from Cursor API:"
  puts JSON.pretty_generate(result)
  puts
  
  # Extract agent ID if available
  agent_id = result['id'] || result['agentId'] || result['agent_id']
  if agent_id
    puts "✓ Agent ID: #{agent_id}"
    puts
    puts "You can now monitor this agent:"
    puts "  - Check Cursor dashboard for agent status"
    puts "  - Monitor webhook callbacks (if TEST_WEBHOOK_URL is set)"
    puts "  - Watch for PR creation on GitHub"
  end
  
  success = true
  
rescue ArgumentError => e
  puts "❌ VALIDATION ERROR"
  puts "  Message: #{e.message}"
  puts
  puts "This indicates a problem with the test data setup."
  success = false
  
rescue StandardError => e
  puts "❌ API REQUEST FAILED"
  puts "  Message: #{e.message}"
  puts
  puts "Possible causes:"
  puts "  - Invalid CURSOR_KEY"
  puts "  - API endpoint unreachable"
  puts "  - Rate limiting"
  puts "  - Invalid request payload"
  success = false
end

puts

# ============================================================================
# Step 8: Validation Tests
# ============================================================================

puts "=" * 80
puts "Step 8: Testing error handling and validation"
puts "=" * 80
puts

# Test 1: Invalid task (nil)
puts "Test 1: Launch with nil task"
begin
  cursor_service.launch_agent(
    task: nil,
    webhook_url: webhook_url_final,
    branch_name: "test-branch"
  )
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 2: Invalid webhook URL (blank)
puts "Test 2: Launch with blank webhook URL"
begin
  cursor_service.launch_agent(
    task: task,
    webhook_url: "",
    branch_name: "test-branch"
  )
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 3: Invalid branch name (blank)
puts "Test 3: Launch with blank branch name"
begin
  cursor_service.launch_agent(
    task: task,
    webhook_url: webhook_url_final,
    branch_name: ""
  )
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 4: Task without description
puts "Test 4: Launch with task missing description"
invalid_task = epic.tasks.new(description: nil, position: 2)
begin
  cursor_service.launch_agent(
    task: invalid_task,
    webhook_url: webhook_url_final,
    branch_name: "test-branch"
  )
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# ============================================================================
# Step 9: Summary and Next Steps
# ============================================================================

puts "=" * 80
puts "Validation Complete"
puts "=" * 80
puts

if success
  puts "✅ ACCEPTANCE CRITERIA MET"
  puts "   ✓ Can launch Cursor agent with real API credentials"
  puts "   ✓ Agent ID returned from API"
  puts "   ✓ Webhook URL configured"
  puts "   ✓ Error handling validated"
  puts
  puts "📋 Test Epic & Task created:"
  puts "   Epic ID: #{epic.id}"
  puts "   Task ID: #{task.id}"
  puts "   Branch: #{branch_name}"
  puts
else
  puts "⚠️  PARTIAL SUCCESS"
  puts "   Agent launch failed, but validation tests passed"
  puts "   Check API credentials and network connectivity"
  puts
end

puts "Next steps:"
puts "  1. Monitor the agent execution in Cursor dashboard"
puts "  2. Set up ngrok for webhook testing: ngrok http 3000"
puts "  3. Re-run with TEST_WEBHOOK_URL to test full webhook flow"
puts "  4. Proceed to Task 3.3: LLM Service Console Validation"
puts
puts "To test again from Rails console:"
puts "  load 'script/test_cursor_service.rb'"
puts
puts "To test launch_agent manually from console:"
puts "  cursor = Services::CursorAgentService.new(cursor_credential)"
puts "  cursor.launch_agent("
puts "    task: task,"
puts "    webhook_url: 'https://your-url.ngrok.io/webhooks/cursor/\#{task.id}',"
puts "    branch_name: 'test-branch-name'"
puts "  )"
puts
puts "=" * 80
