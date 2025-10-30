#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Epics::Start interaction
# Usage: rails runner script/test_start_epic_interaction.rb

puts "\n" + "=" * 80
puts "TESTING: Epics::Start Interaction"
puts "=" * 80 + "\n"

# Track test results
test_results = []

def test(name)
  print "Testing: #{name}... "
  result = yield
  if result
    puts "✅ PASS"
    true
  else
    puts "❌ FAIL"
    false
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(3).map { |line| "  #{line}" }.join("\n")
  false
end

begin
  # Setup test data
  puts "\n📝 Setting up test data..."
  
  user = User.create!(
    email: "test-epic-start-#{SecureRandom.hex(4)}@example.com",
    password: 'password123'
  )
  puts "  Created user: #{user.email}"

  github_cred = Credential.create!(
    user: user,
    service_name: 'github',
    name: 'Test GitHub',
    api_key: 'test_github_token'
  )
  puts "  Created GitHub credential"

  cursor_cred = Credential.create!(
    user: user,
    service_name: 'cursor_agent',
    name: 'Test Cursor',
    api_key: 'test_cursor_token'
  )
  puts "  Created Cursor credential"

  repo = Repository.create!(
    user: user,
    name: 'test-repo',
    github_url: 'https://github.com/test/repo',
    github_credential: github_cred
  )
  puts "  Created repository: #{repo.name}"

  # Test 1: Create epic with tasks
  puts "\n" + "-" * 80
  puts "Test 1: Basic Epic Start"
  puts "-" * 80
  
  tasks_json = [
    'Task 1: Setup database',
    'Task 2: Create API endpoints',
    'Task 3: Add tests'
  ].to_json

  result = Epics::CreateFromManualSpec.run!(
    user: user,
    repository: repo,
    tasks_json: tasks_json,
    base_branch: 'main',
    cursor_agent_credential_id: cursor_cred.id
  )
  
  epic = result[:epic]
  tasks = result[:tasks]
  
  puts "  Epic created: #{epic.title}"
  puts "  Tasks created: #{tasks.count}"
  puts "  Epic status: #{epic.status}"

  test_results << test("Epic is in pending status") do
    epic.status == 'pending'
  end

  test_results << test("Epic has 3 tasks") do
    epic.tasks.count == 3
  end

  # Test 2: Start the epic
  puts "\n" + "-" * 80
  puts "Test 2: Starting Epic"
  puts "-" * 80

  # Mock the job to test without actually enqueuing
  job_enqueued = false
  enqueued_task_id = nil
  
  allow(Tasks::ExecuteJob).to receive(:perform_async) do |task_id|
    job_enqueued = true
    enqueued_task_id = task_id
    puts "  📩 Job enqueued for task ID: #{task_id}"
  end

  outcome = Epics::Start.run(user: user, epic: epic)

  test_results << test("Interaction is valid") do
    outcome.valid?
  end

  test_results << test("Epic status changed to running") do
    epic.reload
    epic.status == 'running'
  end

  test_results << test("Job was enqueued") do
    job_enqueued
  end

  test_results << test("Job enqueued for first task") do
    first_task = tasks.min_by(&:position)
    enqueued_task_id == first_task.id
  end

  puts "  Epic status after start: #{epic.status}"
  puts "  First task ID: #{tasks.first.id}"
  puts "  Enqueued task ID: #{enqueued_task_id}"

  # Test 3: Try to start already running epic
  puts "\n" + "-" * 80
  puts "Test 3: Error Handling - Already Running Epic"
  puts "-" * 80

  outcome2 = Epics::Start.run(user: user, epic: epic)

  test_results << test("Second start fails validation") do
    !outcome2.valid?
  end

  test_results << test("Error message is correct") do
    outcome2.errors[:epic]&.include?('must be in pending status to start')
  end

  if outcome2.errors.any?
    puts "  Expected errors: #{outcome2.errors.full_messages.join(', ')}"
  end

  # Test 4: Create epic without tasks
  puts "\n" + "-" * 80
  puts "Test 4: Error Handling - Epic Without Tasks"
  puts "-" * 80

  empty_epic = Epic.create!(
    user: user,
    repository: repo,
    title: 'Empty Epic',
    prompt: 'Test prompt',
    base_branch: 'main',
    status: :pending
  )

  outcome3 = Epics::Start.run(user: user, epic: empty_epic)

  test_results << test("Empty epic fails validation") do
    !outcome3.valid?
  end

  test_results << test("Error message mentions tasks") do
    outcome3.errors[:epic]&.include?('must have at least one task')
  end

  if outcome3.errors.any?
    puts "  Expected errors: #{outcome3.errors.full_messages.join(', ')}"
  end

  # Test 5: Wrong user
  puts "\n" + "-" * 80
  puts "Test 5: Error Handling - Wrong User"
  puts "-" * 80

  other_user = User.create!(
    email: "other-user-#{SecureRandom.hex(4)}@example.com",
    password: 'password123'
  )

  # Create a new pending epic for this test
  new_epic = Epic.create!(
    user: user,
    repository: repo,
    title: 'Test Epic',
    prompt: 'Test prompt',
    base_branch: 'main',
    status: :pending,
    cursor_agent_credential: cursor_cred
  )
  Task.create!(epic: new_epic, description: 'Some task', position: 0, status: :pending)

  outcome4 = Epics::Start.run(user: other_user, epic: new_epic)

  test_results << test("Wrong user fails validation") do
    !outcome4.valid?
  end

  test_results << test("Error message mentions user ownership") do
    outcome4.errors[:epic]&.include?('must belong to the user')
  end

  if outcome4.errors.any?
    puts "  Expected errors: #{outcome4.errors.full_messages.join(', ')}"
  end

  # Test 6: Epic with only completed tasks
  puts "\n" + "-" * 80
  puts "Test 6: Epic With No Pending Tasks"
  puts "-" * 80

  completed_epic = Epic.create!(
    user: user,
    repository: repo,
    title: 'Completed Tasks Epic',
    prompt: 'Test prompt',
    base_branch: 'main',
    status: :pending,
    cursor_agent_credential: cursor_cred
  )
  
  Task.create!(epic: completed_epic, description: 'Done task 1', position: 0, status: :completed)
  Task.create!(epic: completed_epic, description: 'Done task 2', position: 1, status: :completed)

  job_enqueued_6 = false
  allow(Tasks::ExecuteJob).to receive(:perform_async) do |task_id|
    job_enqueued_6 = true
  end

  outcome5 = Epics::Start.run(user: user, epic: completed_epic)

  test_results << test("Epic with no pending tasks is valid") do
    outcome5.valid?
  end

  test_results << test("Epic status changes to running") do
    completed_epic.reload.status == 'running'
  end

  test_results << test("No job is enqueued") do
    !job_enqueued_6
  end

  puts "  Epic status: #{completed_epic.status}"
  puts "  Job enqueued: #{job_enqueued_6}"

  # Test 7: Task position ordering
  puts "\n" + "-" * 80
  puts "Test 7: Task Position Ordering"
  puts "-" * 80

  ordered_epic = Epic.create!(
    user: user,
    repository: repo,
    title: 'Ordered Epic',
    prompt: 'Test prompt',
    base_branch: 'main',
    status: :pending,
    cursor_agent_credential: cursor_cred
  )
  
  # Create tasks in reverse order
  task_c = Task.create!(epic: ordered_epic, description: 'Task at position 2', position: 2, status: :pending)
  task_b = Task.create!(epic: ordered_epic, description: 'Task at position 1', position: 1, status: :pending)
  task_a = Task.create!(epic: ordered_epic, description: 'Task at position 0', position: 0, status: :pending)

  enqueued_task_id_7 = nil
  allow(Tasks::ExecuteJob).to receive(:perform_async) do |task_id|
    enqueued_task_id_7 = task_id
  end

  outcome6 = Epics::Start.run(user: user, epic: ordered_epic)

  test_results << test("Job enqueued for task with lowest position") do
    enqueued_task_id_7 == task_a.id
  end

  puts "  Task A (position 0) ID: #{task_a.id}"
  puts "  Task B (position 1) ID: #{task_b.id}"
  puts "  Task C (position 2) ID: #{task_c.id}"
  puts "  Enqueued task ID: #{enqueued_task_id_7}"

  # Test 8: Multiple epics
  puts "\n" + "-" * 80
  puts "Test 8: Multiple Epics Independence"
  puts "-" * 80

  epic_1 = Epic.create!(
    user: user,
    repository: repo,
    title: 'Epic 1',
    prompt: 'Test',
    base_branch: 'main',
    status: :pending,
    cursor_agent_credential: cursor_cred
  )
  Task.create!(epic: epic_1, description: 'Task 1', position: 0, status: :pending)

  epic_2 = Epic.create!(
    user: user,
    repository: repo,
    title: 'Epic 2',
    prompt: 'Test',
    base_branch: 'main',
    status: :pending,
    cursor_agent_credential: cursor_cred
  )
  Task.create!(epic: epic_2, description: 'Task 2', position: 0, status: :pending)

  # Start first epic
  allow(Tasks::ExecuteJob).to receive(:perform_async)
  Epics::Start.run!(user: user, epic: epic_1)

  test_results << test("First epic status is running") do
    epic_1.reload.status == 'running'
  end

  test_results << test("Second epic status is still pending") do
    epic_2.reload.status == 'pending'
  end

  puts "  Epic 1 status: #{epic_1.status}"
  puts "  Epic 2 status: #{epic_2.status}"

  # Summary
  puts "\n" + "=" * 80
  puts "TEST SUMMARY"
  puts "=" * 80
  
  passed = test_results.count(true)
  failed = test_results.count(false)
  total = test_results.count
  
  puts "✅ Passed: #{passed}/#{total}"
  puts "❌ Failed: #{failed}/#{total}" if failed > 0
  puts "\n"

  if failed == 0
    puts "🎉 All tests passed!"
  else
    puts "⚠️  Some tests failed. Please review the output above."
  end

ensure
  # Cleanup
  puts "\n🧹 Cleaning up test data..."
  
  if defined?(user) && user
    Epic.where(user: user).destroy_all
    Repository.where(user: user).destroy_all
    Credential.where(user: user).destroy_all
    user.destroy
  end
  
  if defined?(other_user) && other_user
    other_user.destroy
  end
  
  puts "✨ Cleanup complete!"
  puts "\n"
end
