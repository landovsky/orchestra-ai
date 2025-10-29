#!/usr/bin/env ruby
# Script to manually test Epics::CreateFromManualSpec interaction

require_relative '../config/environment'

puts "Testing Epics::CreateFromManualSpec interaction"
puts "=" * 50

# Create test data
user = User.first || User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

repository = user.repositories.first || Repository.create!(
  user: user,
  name: 'test-repo',
  github_url: 'https://github.com/test/test-repo',
  github_credential: Credential.create!(
    user: user,
    service_name: 'github',
    name: 'Test GitHub',
    api_key: 'test-key'
  )
)

# Test 1: Basic creation
puts "\nTest 1: Creating Epic with 3 tasks"
puts "-" * 50

tasks = [
  "Task 1: Setup database schema",
  "Task 2: Add API endpoints",
  "Task 3: Write comprehensive tests"
]

outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repository,
  tasks_json: tasks.to_json,
  base_branch: 'main'
)

if outcome.valid?
  epic = outcome.result[:epic]
  created_tasks = outcome.result[:tasks]
  
  puts "✓ Epic created successfully!"
  puts "  ID: #{epic.id}"
  puts "  Title: #{epic.title}"
  puts "  Status: #{epic.status}"
  puts "  Base Branch: #{epic.base_branch}"
  puts "  Number of tasks: #{created_tasks.size}"
  puts "\nTasks with positions:"
  created_tasks.each do |task|
    puts "  [#{task.position}] #{task.description}"
  end
  
  # Verify task ordering from database
  puts "\nVerifying task order from database:"
  epic.reload
  epic.tasks.ordered.each do |task|
    puts "  [#{task.position}] #{task.description}"
  end
  
  puts "\n✓ Test 1 PASSED"
else
  puts "✗ Test 1 FAILED"
  puts "Errors: #{outcome.errors.full_messages.join(', ')}"
end

# Test 2: Task positions
puts "\n\nTest 2: Verifying task positions are sequential"
puts "-" * 50

positions = outcome.result[:tasks].map(&:position)
expected = (0...tasks.size).to_a

if positions == expected
  puts "✓ Task positions are correct: #{positions.inspect}"
  puts "✓ Test 2 PASSED"
else
  puts "✗ Test 2 FAILED"
  puts "Expected: #{expected.inspect}"
  puts "Got: #{positions.inspect}"
end

# Test 3: Invalid JSON
puts "\n\nTest 3: Testing with invalid JSON"
puts "-" * 50

outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repository,
  tasks_json: 'not valid json',
  base_branch: 'main'
)

if !outcome.valid? && outcome.errors[:tasks_json].present?
  puts "✓ Correctly rejected invalid JSON"
  puts "  Error: #{outcome.errors[:tasks_json].first}"
  puts "✓ Test 3 PASSED"
else
  puts "✗ Test 3 FAILED - Should have rejected invalid JSON"
end

# Test 4: Empty array
puts "\n\nTest 4: Testing with empty tasks array"
puts "-" * 50

outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repository,
  tasks_json: '[]',
  base_branch: 'main'
)

if !outcome.valid? && outcome.errors[:tasks_json].present?
  puts "✓ Correctly rejected empty array"
  puts "  Error: #{outcome.errors[:tasks_json].first}"
  puts "✓ Test 4 PASSED"
else
  puts "✗ Test 4 FAILED - Should have rejected empty array"
end

# Test 5: Large task list
puts "\n\nTest 5: Testing with 10 tasks"
puts "-" * 50

large_tasks = (1..10).map { |i| "Task #{i}: Implement feature #{i}" }

outcome = Epics::CreateFromManualSpec.run(
  user: user,
  repository: repository,
  tasks_json: large_tasks.to_json,
  base_branch: 'main'
)

if outcome.valid? && outcome.result[:tasks].size == 10
  positions = outcome.result[:tasks].map(&:position)
  expected = (0..9).to_a
  
  if positions == expected
    puts "✓ Created 10 tasks with correct positions"
    puts "  Positions: #{positions.inspect}"
    puts "✓ Test 5 PASSED"
  else
    puts "✗ Test 5 FAILED - Incorrect positions"
    puts "  Expected: #{expected.inspect}"
    puts "  Got: #{positions.inspect}"
  end
else
  puts "✗ Test 5 FAILED"
  puts "Errors: #{outcome.errors.full_messages.join(', ')}" if !outcome.valid?
end

puts "\n" + "=" * 50
puts "Testing complete!"
