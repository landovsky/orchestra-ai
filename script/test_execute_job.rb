# frozen_string_literal: true

# Test script for Tasks::ExecuteJob
#
# This script demonstrates how to test the ExecuteJob from the Rails console
# Usage: rails runner script/test_execute_job.rb

puts "=" * 80
puts "Testing Tasks::ExecuteJob"
puts "=" * 80
puts

# Step 1: Find or create test data
puts "Step 1: Setting up test data..."

user = User.first
unless user
  puts "❌ No user found. Creating one..."
  user = User.create!(
    email: "test@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  puts "✓ Created user: #{user.email}"
end

# Find or create Cursor credential
cursor_cred = Credential.find_by(user: user, service_name: 'cursor_agent')
unless cursor_cred
  if ENV['CURSOR_KEY'].blank?
    puts "❌ No CURSOR_KEY environment variable found"
    puts "   Please set: export CURSOR_KEY='your-cursor-api-key'"
    exit 1
  end
  cursor_cred = Credential.create!(
    user: user,
    service_name: 'cursor_agent',
    name: 'Test Cursor Credential',
    api_key: ENV['CURSOR_KEY']
  )
  puts "✓ Created Cursor credential"
else
  puts "✓ Found Cursor credential: #{cursor_cred.name}"
end

# Find or create GitHub credential
github_cred = Credential.find_by(user: user, service_name: 'github')
unless github_cred
  if ENV['GITHUB_TOKEN'].blank?
    puts "❌ No GITHUB_TOKEN environment variable found"
    puts "   Please set: export GITHUB_TOKEN='your-github-token'"
    exit 1
  end
  github_cred = Credential.create!(
    user: user,
    service_name: 'github',
    name: 'Test GitHub Credential',
    api_key: ENV['GITHUB_TOKEN']
  )
  puts "✓ Created GitHub credential"
else
  puts "✓ Found GitHub credential: #{github_cred.name}"
end

# Find or create repository
repo = Repository.find_by(user: user)
unless repo
  puts "❌ No repository found. Creating one..."
  puts "   Enter GitHub repository URL (e.g., https://github.com/user/repo): "
  repo_url = STDIN.gets.chomp
  repo_name = repo_url.split('/').last
  
  repo = Repository.create!(
    user: user,
    name: repo_name,
    github_url: repo_url,
    github_credential: github_cred
  )
  puts "✓ Created repository: #{repo.name}"
else
  puts "✓ Found repository: #{repo.name} (#{repo.github_url})"
end

# Find or create epic
epic = Epic.find_by(user: user, repository: repo)
unless epic
  puts "Creating test epic..."
  epic = Epic.create!(
    user: user,
    repository: repo,
    title: "Test Epic for ExecuteJob",
    base_branch: "main",
    cursor_agent_credential: cursor_cred,
    status: 'running'
  )
  puts "✓ Created epic: #{epic.title}"
else
  puts "✓ Found epic: #{epic.title}"
  # Update cursor credential if not set
  if epic.cursor_agent_credential.nil?
    epic.update!(cursor_agent_credential: cursor_cred)
    puts "✓ Updated epic with Cursor credential"
  end
end

# Find or create task
task = epic.tasks.find_by(status: ['pending', 'failed'])
unless task
  puts "Creating test task..."
  task = Task.create!(
    epic: epic,
    description: "Add a comment to the README.md file explaining what this repository does",
    position: epic.tasks.count,
    status: 'pending'
  )
  puts "✓ Created task: #{task.description[0..50]}..."
else
  puts "✓ Found task: #{task.description[0..50]}..."
end

puts
puts "=" * 80
puts "Step 2: Executing the job..."
puts "=" * 80
puts
puts "Task ID: #{task.id}"
puts "Task Status: #{task.status}"
puts "Task Description: #{task.description}"
puts

# Make sure APP_URL is set for webhook generation
if ENV['APP_URL'].blank?
  puts "⚠️  APP_URL not set, using default: http://localhost:3000"
  ENV['APP_URL'] = 'http://localhost:3000'
end

# Execute the job
begin
  puts "Executing Tasks::ExecuteJob.new.perform(#{task.id})..."
  puts
  
  Tasks::ExecuteJob.new.perform(task.id)
  
  puts
  puts "=" * 80
  puts "✓ Job completed successfully!"
  puts "=" * 80
  puts
  
  # Reload task to see updated values
  task.reload
  
  puts "Updated Task Details:"
  puts "-" * 80
  puts "Status:           #{task.status}"
  puts "Cursor Agent ID:  #{task.cursor_agent_id}"
  puts "Branch Name:      #{task.branch_name}"
  puts
  puts "Debug Log:"
  puts "-" * 80
  puts task.debug_log
  puts
  
  if task.cursor_agent_id.present? && task.branch_name.present?
    puts "✅ SUCCESS: Agent launched and details saved!"
  else
    puts "⚠️  WARNING: Job completed but some fields are missing"
    puts "   Cursor Agent ID: #{task.cursor_agent_id.present? ? '✓' : '✗'}"
    puts "   Branch Name: #{task.branch_name.present? ? '✓' : '✗'}"
  end
  
rescue StandardError => e
  puts
  puts "=" * 80
  puts "❌ Job failed with error:"
  puts "=" * 80
  puts e.message
  puts
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")
  puts
  
  # Still reload task to see if any updates were made
  task.reload
  puts "Task Status: #{task.status}"
  puts
  puts "Debug Log:"
  puts "-" * 80
  puts task.debug_log
end

puts
puts "=" * 80
puts "Test Complete"
puts "=" * 80
