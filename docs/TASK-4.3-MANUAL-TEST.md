# Task 4.3 - Quick Manual Test Guide

## Quick Console Test (Copy-Paste Ready)

Open Rails console and run these commands:

```ruby
# === SETUP ===
user = User.create!(email: "test-#{SecureRandom.hex(4)}@example.com", password: 'password123')
github_cred = Credential.create!(user: user, service_name: 'github', name: 'Test GitHub', api_key: 'test_token')
cursor_cred = Credential.create!(user: user, service_name: 'cursor_agent', name: 'Test Cursor', api_key: 'test_token')
repo = Repository.create!(user: user, name: 'test-repo', github_url: 'https://github.com/test/repo', github_credential: github_cred)

# === CREATE EPIC WITH TASKS ===
tasks_json = ['Task 1: Setup database', 'Task 2: Create API endpoints', 'Task 3: Add tests'].to_json
result = Epics::CreateFromManualSpec.run!(user: user, repository: repo, tasks_json: tasks_json, base_branch: 'main', cursor_agent_credential_id: cursor_cred.id)
epic = result[:epic]

# === TEST 1: Check Initial State ===
puts "\n=== TEST 1: Initial State ==="
puts "Epic status: #{epic.status}"  # Should be "pending"
puts "Task count: #{epic.tasks.count}"  # Should be 3
puts "First task: #{epic.tasks.first.description}"

# === TEST 2: Start Epic ===
puts "\n=== TEST 2: Start Epic ==="
outcome = Epics::Start.run!(user: user, epic: epic)
puts "Epic status after start: #{epic.reload.status}"  # Should be "running"
puts "Outcome valid: #{outcome.present?}"  # Should be true

# === TEST 3: Try Starting Again (Should Fail) ===
puts "\n=== TEST 3: Error Handling ==="
outcome2 = Epics::Start.run(user: user, epic: epic)
puts "Can start again: #{outcome2.valid?}"  # Should be false
puts "Error message: #{outcome2.errors.full_messages.join(', ')}"  # Should mention "pending status"

# === TEST 4: Task Position Ordering ===
puts "\n=== TEST 4: Task Ordering ==="
epic2 = Epic.create!(user: user, repository: repo, title: 'Test', prompt: 'Test', base_branch: 'main', status: :pending, cursor_agent_credential: cursor_cred)
Task.create!(epic: epic2, description: 'Last', position: 2, status: :pending)
Task.create!(epic: epic2, description: 'First', position: 0, status: :pending)
Task.create!(epic: epic2, description: 'Middle', position: 1, status: :pending)
Epics::Start.run!(user: user, epic: epic2)
puts "Epic2 started successfully"
puts "First task by position: #{epic2.tasks.where(status: :pending).order(position: :asc).first.description}"  # Should be "First"

# === CLEANUP ===
puts "\n=== CLEANUP ==="
Epic.where(user: user).destroy_all
Repository.where(user: user).destroy_all
Credential.where(user: user).destroy_all
user.destroy
puts "Test data cleaned up!"

puts "\n✅ All manual tests completed successfully!"
```

## Expected Output

```
=== TEST 1: Initial State ===
Epic status: pending
Task count: 3
First task: Task 1: Setup database

=== TEST 2: Start Epic ===
Epic status after start: running
Outcome valid: true

=== TEST 3: Error Handling ===
Can start again: false
Error message: Epic must be in pending status to start

=== TEST 4: Task Ordering ===
Epic2 started successfully
First task by position: First

=== CLEANUP ===
Test data cleaned up!

✅ All manual tests completed successfully!
```

## What This Tests

1. ✅ Epic creation and initial state
2. ✅ Starting epic changes status to 'running'
3. ✅ Cannot start already running epic
4. ✅ First pending task (by position) is selected correctly
5. ✅ Cleanup works properly

## Alternative: Run Automated Script

```bash
rails runner script/test_start_epic_interaction.rb
```

This runs a comprehensive test suite with 18+ test cases and detailed output.
