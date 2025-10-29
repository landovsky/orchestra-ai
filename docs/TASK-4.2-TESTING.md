# Task 4.2: Tasks::UpdateStatus Interaction - Testing Guide

## Overview
This document provides instructions for testing the `Tasks::UpdateStatus` interaction, which handles task status updates with logging and broadcasting functionality.

## Implementation Summary

### Files Created
1. **`app/interactions/tasks/update_status.rb`** - Main interaction class
2. **`spec/interactions/tasks/update_status_spec.rb`** - Comprehensive RSpec test suite
3. **`script/test_update_status_interaction.rb`** - Console test script

### Features Implemented
- ✅ Task status updates with validation
- ✅ PR URL updates
- ✅ Debug log appending with timestamps
- ✅ Turbo Stream broadcasting
- ✅ Transaction safety (rollback on errors)
- ✅ Error handling for broadcast failures

## Running Tests

### 1. Run RSpec Test Suite

```bash
cd /workspace
bundle exec rspec spec/interactions/tasks/update_status_spec.rb -fd
```

The test suite includes:
- ✅ 25+ comprehensive test cases
- ✅ Valid input scenarios
- ✅ Invalid input validation
- ✅ Log appending with multiple entries
- ✅ Broadcasting functionality
- ✅ Transaction rollback behavior
- ✅ Edge cases and error handling

### 2. Run Console Test Script

From Rails console:
```ruby
load 'script/test_update_status_interaction.rb'
```

Or from command line:
```bash
rails runner script/test_update_status_interaction.rb
```

The script tests:
1. Basic status updates
2. Log message appending
3. PR URL updates
4. Multiple sequential updates
5. Invalid status handling
6. Full workflow transitions
7. Edge cases (empty/nil values)

### 3. Manual Console Testing

Open Rails console:
```bash
rails console
```

#### Basic Status Update
```ruby
# Create test data
user = User.first || User.create!(email: "test@example.com", password: "password123")
repo = Repository.first || user.repositories.create!(
  name: "test-repo",
  github_url: "https://github.com/test/repo",
  github_credential: user.credentials.create!(service_name: 'github', name: 'Test', api_key: 'key')
)
epic = Epic.create!(
  user: user,
  repository: repo,
  title: "Test Epic",
  prompt: "Test",
  base_branch: "main"
)
task = Task.create!(
  epic: epic,
  description: "Test task",
  position: 0
)

# Test 1: Update status
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running'
)
task.reload.status
# => "running"
```

#### Status Update with Log Message
```ruby
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running',
  log_message: "Starting Cursor agent..."
)
task.reload.debug_log
# => "[2025-10-29 14:30:45] Starting Cursor agent..."
```

#### Status Update with PR URL
```ruby
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'pr_open',
  log_message: "PR created successfully",
  pr_url: "https://github.com/user/repo/pull/123"
)
task.reload
task.status        # => "pr_open"
task.pr_url        # => "https://github.com/user/repo/pull/123"
task.debug_log     # Shows both log entries
```

#### Multiple Log Appends
```ruby
# First update
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running',
  log_message: "Agent started"
)

# Second update
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'pr_open',
  log_message: "PR created"
)

# Third update
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'completed',
  log_message: "PR merged"
)

# Check log
task.reload.debug_log
# Shows all three entries with timestamps
```

#### Test Invalid Status
```ruby
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'invalid_status'
)
outcome.valid?
# => false
outcome.errors[:new_status]
# => ["must be one of: pending, running, pr_open, merging, completed, failed"]
```

## Validation Rules

The interaction validates:
1. **new_status** must be one of: `pending`, `running`, `pr_open`, `merging`, `completed`, `failed`
2. **task** must be a valid Task object
3. **log_message** is optional (nil or string)
4. **pr_url** is optional (nil or string)

## Log Format

Debug logs are appended with timestamps:
```
[2025-10-29 14:30:45] Starting Cursor agent...
[2025-10-29 14:31:12] PR created successfully
[2025-10-29 14:32:00] PR merged and deployed
```

## Broadcasting

The interaction broadcasts Turbo Stream updates to:
- **Channel**: `epic_#{task.epic_id}`
- **Target**: `task_#{task.id}`
- **Partial**: `tasks/task`

Note: Broadcasting errors are logged but don't fail the transaction.

## Acceptance Criteria

All acceptance criteria from Task 4.2 have been met:

✅ **Tasks::UpdateStatus interaction created** with:
  - Status update functionality
  - Optional log message appending
  - Optional PR URL updates
  - Turbo Stream broadcasting

✅ **Status updates work correctly**:
  - All valid statuses can be set
  - Invalid statuses are rejected
  - Status changes persist to database

✅ **Log appending works correctly**:
  - Logs append with timestamps
  - Multiple log entries are preserved
  - Empty logs are handled gracefully
  - Nil debug_log is handled

✅ **Comprehensive test coverage**:
  - 25+ RSpec tests
  - Console test script
  - Manual testing guide

## Next Steps

After testing is complete, this interaction can be used by:
- **Tasks::ExecuteJob** (Phase 5.1)
- **Webhooks::CursorController** (Phase 5.2-5.3)
- **Tasks::MergeJob** (Phase 7)

## Reference Files

- Specification: `docs/spec-orchestrator.md` (lines 75-81)
- Implementation plan: `docs/implementation-tasks.md` (lines 85-97)
- Interaction class: `app/interactions/tasks/update_status.rb`
- Test suite: `spec/interactions/tasks/update_status_spec.rb`
- Console script: `script/test_update_status_interaction.rb`
