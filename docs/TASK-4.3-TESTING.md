# Task 4.3 Testing Guide: Epics::Start Interaction

## Overview
This guide provides instructions for testing the `Epics::Start` interaction that starts epics manually from console, changes epic status, and enqueues the first task job.

---

## Running RSpec Tests

### Run All Tests
```bash
bundle exec rspec spec/interactions/epics/start_spec.rb -fd
```

### Run Specific Test Context
```bash
# Test valid inputs only
bundle exec rspec spec/interactions/epics/start_spec.rb -e "with valid inputs"

# Test invalid status handling
bundle exec rspec spec/interactions/epics/start_spec.rb -e "with invalid epic status"

# Test user ownership
bundle exec rspec spec/interactions/epics/start_spec.rb -e "with invalid epic ownership"

# Test task ordering
bundle exec rspec spec/interactions/epics/start_spec.rb -e "with mixed task statuses"
```

---

## Running Console Test Script

### Automated Test Script
```bash
rails runner script/test_start_epic_interaction.rb
```

**What it tests:**
1. ✅ Basic epic start functionality
2. ✅ Epic status changes to 'running'
3. ✅ Job enqueuing for first task
4. ✅ Error handling for already running epic
5. ✅ Error handling for epic without tasks
6. ✅ Error handling for wrong user
7. ✅ Epic with all completed tasks
8. ✅ Task position ordering
9. ✅ Multiple epics independence

**Expected Output:**
```
================================================================================
TESTING: Epics::Start Interaction
================================================================================

📝 Setting up test data...
  Created user: test-epic-start-xxxx@example.com
  Created GitHub credential
  Created Cursor credential
  Created repository: test-repo

--------------------------------------------------------------------------------
Test 1: Basic Epic Start
--------------------------------------------------------------------------------
  Epic created: Task 1: Setup database
  Tasks created: 3
  Epic status: pending
Testing: Epic is in pending status... ✅ PASS
Testing: Epic has 3 tasks... ✅ PASS

--------------------------------------------------------------------------------
Test 2: Starting Epic
--------------------------------------------------------------------------------
  📩 Job enqueued for task ID: 123
Testing: Interaction is valid... ✅ PASS
Testing: Epic status changed to running... ✅ PASS
Testing: Job was enqueued... ✅ PASS
Testing: Job enqueued for first task... ✅ PASS
  Epic status after start: running
  First task ID: 123
  Enqueued task ID: 123

[... more tests ...]

================================================================================
TEST SUMMARY
================================================================================
✅ Passed: 18/18

🎉 All tests passed!

🧹 Cleaning up test data...
✨ Cleanup complete!
```

---

## Manual Console Testing

### Setup Test Data
```bash
rails console
```

```ruby
# Create user
user = User.create!(
  email: "test-#{SecureRandom.hex(4)}@example.com",
  password: 'password123'
)

# Create credentials
github_cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'Test GitHub',
  api_key: 'test_token'
)

cursor_cred = Credential.create!(
  user: user,
  service_name: 'cursor_agent',
  name: 'Test Cursor',
  api_key: 'test_token'
)

# Create repository
repo = Repository.create!(
  user: user,
  name: 'test-repo',
  github_url: 'https://github.com/test/repo',
  github_credential: github_cred
)

# Create epic with tasks
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
```

### Test 1: Basic Epic Start
```ruby
# Check initial state
epic.status
# => "pending"

epic.tasks.pluck(:description, :status)
# => [["Task 1: Setup database", "pending"],
#     ["Task 2: Create API endpoints", "pending"],
#     ["Task 3: Add tests", "pending"]]

# Start the epic
outcome = Epics::Start.run!(user: user, epic: epic)

# Verify results
outcome.class
# => Epic

epic.reload.status
# => "running"

# Check Sidekiq (if running)
Sidekiq::Queue.new.size
# => 1 (job was enqueued)
```

### Test 2: Error - Already Running
```ruby
# Try to start again
outcome = Epics::Start.run(user: user, epic: epic)

outcome.valid?
# => false

outcome.errors.full_messages
# => ["Epic must be in pending status to start"]
```

### Test 3: Error - Wrong User
```ruby
other_user = User.create!(
  email: "other-#{SecureRandom.hex(4)}@example.com",
  password: 'password123'
)

# Try to start epic with wrong user
outcome = Epics::Start.run(user: other_user, epic: epic)

outcome.valid?
# => false

outcome.errors.full_messages
# => ["Epic must belong to the user"]
```

### Test 4: Error - No Tasks
```ruby
empty_epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'Empty Epic',
  prompt: 'Test',
  base_branch: 'main',
  status: :pending
)

outcome = Epics::Start.run(user: user, epic: empty_epic)

outcome.valid?
# => false

outcome.errors.full_messages
# => ["Epic must have at least one task"]
```

### Test 5: Task Position Ordering
```ruby
# Create epic with tasks in reverse order
ordered_epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'Ordered Epic',
  prompt: 'Test',
  base_branch: 'main',
  status: :pending,
  cursor_agent_credential: cursor_cred
)

# Create tasks in reverse order
task_c = Task.create!(
  epic: ordered_epic,
  description: 'Task at position 2',
  position: 2,
  status: :pending
)

task_b = Task.create!(
  epic: ordered_epic,
  description: 'Task at position 1',
  position: 1,
  status: :pending
)

task_a = Task.create!(
  epic: ordered_epic,
  description: 'Task at position 0',
  position: 0,
  status: :pending
)

# Start epic (should enqueue task_a)
Epics::Start.run!(user: user, epic: ordered_epic)

# Verify correct task was enqueued (check logs or Sidekiq)
# Job should be enqueued for task_a (position 0)
```

### Test 6: Skip Completed Tasks
```ruby
# Create epic with mixed task statuses
mixed_epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'Mixed Epic',
  prompt: 'Test',
  base_branch: 'main',
  status: :pending,
  cursor_agent_credential: cursor_cred
)

task1 = Task.create!(
  epic: mixed_epic,
  description: 'Completed task',
  position: 0,
  status: :completed
)

task2 = Task.create!(
  epic: mixed_epic,
  description: 'Pending task',
  position: 1,
  status: :pending
)

# Start epic (should enqueue task2, skip task1)
Epics::Start.run!(user: user, epic: mixed_epic)

# Job should be enqueued for task2 (first pending task)
```

### Test 7: No Pending Tasks
```ruby
all_done_epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'All Done Epic',
  prompt: 'Test',
  base_branch: 'main',
  status: :pending,
  cursor_agent_credential: cursor_cred
)

Task.create!(
  epic: all_done_epic,
  description: 'Done 1',
  position: 0,
  status: :completed
)

Task.create!(
  epic: all_done_epic,
  description: 'Done 2',
  position: 1,
  status: :completed
)

# Start epic (should succeed but not enqueue job)
outcome = Epics::Start.run!(user: user, epic: all_done_epic)

outcome.valid?
# => true

all_done_epic.reload.status
# => "running"

# No job should be enqueued (check Sidekiq queue)
```

### Cleanup
```ruby
# Clean up test data
Epic.where(user: user).destroy_all
Repository.where(user: user).destroy_all
Credential.where(user: user).destroy_all
user.destroy

# If created other_user:
other_user.destroy if defined?(other_user)
```

---

## Validation Rules Reference

### Epic Status Validation
| Status | Can Start? | Error Message |
|--------|-----------|---------------|
| `pending` | ✅ Yes | - |
| `running` | ❌ No | "must be in pending status to start" |
| `completed` | ❌ No | "must be in pending status to start" |
| `failed` | ❌ No | "must be in pending status to start" |
| `paused` | ❌ No | "must be in pending status to start" |
| `generating_spec` | ❌ No | "must be in pending status to start" |

### Other Validations
| Validation | Requirement | Error Message |
|------------|-------------|---------------|
| User ownership | `epic.user_id == user.id` | "must belong to the user" |
| Has tasks | `epic.tasks.any?` | "must have at least one task" |

---

## Expected Behavior Summary

### When Successful
1. ✅ Epic status changes from 'pending' to 'running'
2. ✅ Tasks::ExecuteJob enqueued for first pending task (by position)
3. ✅ Turbo Stream broadcast sent (or logged if fails)
4. ✅ Interaction returns the updated epic object

### When No Pending Tasks
1. ✅ Epic status changes to 'running'
2. ✅ No job is enqueued (since no pending tasks)
3. ✅ No errors (this is valid scenario)

### When Invalid
1. ❌ Epic status does not change
2. ❌ No job is enqueued
3. ❌ Interaction returns outcome with errors
4. ❌ All changes rolled back (transaction)

---

## Checking Job Enqueuing

### If Sidekiq is Running
```ruby
# Check queue size
Sidekiq::Queue.new.size

# Inspect jobs
Sidekiq::Queue.new.map { |job| [job.klass, job.args] }
# => [["Tasks::ExecuteJob", [123]]]

# Clear queue (for testing)
Sidekiq::Queue.new.clear
```

### If Using perform_async Mock
```ruby
# In tests, you can mock it
allow(Tasks::ExecuteJob).to receive(:perform_async) do |task_id|
  puts "Job enqueued for task #{task_id}"
end
```

---

## Common Issues

### Issue: "undefined method `perform_async`"
**Cause**: Sidekiq not loaded or job not properly defined

**Solution**:
```ruby
# Make sure Sidekiq is loaded
require 'sidekiq'

# Or mock it in tests
allow(Tasks::ExecuteJob).to receive(:perform_async)
```

### Issue: Broadcasting fails but transaction succeeds
**Expected**: Broadcasting failures are caught and logged, transaction continues

**Verify**:
```ruby
# Check logs
Rails.logger.level = :debug
Epics::Start.run!(user: user, epic: epic)
# Should see error log if broadcast fails, but interaction still succeeds
```

### Issue: Epic has tasks but validation fails
**Cause**: Tasks were loaded before transaction, need reload

**Solution**:
```ruby
epic.reload
epic.tasks.count  # Should show correct count
```

---

## Next Steps After Testing

1. ✅ All tests pass → Move to Phase 5.1 (Tasks::ExecuteJob implementation)
2. ❌ Tests fail → Review errors, fix issues, re-test
3. 🔄 Need modifications → Update interaction, update tests, re-test

---

## Related Documentation

- `docs/spec-orchestrator.md` - Full system specification
- `docs/implementation-tasks.md` - Implementation plan
- `docs/TASK-4.3-COMPLETED.md` - Completion summary
- `docs/TASK-4.2-COMPLETED.md` - Tasks::UpdateStatus (previous task)
- `app/interactions/epics/start.rb` - Source code
- `spec/interactions/epics/start_spec.rb` - RSpec tests
- `script/test_start_epic_interaction.rb` - Console test script
