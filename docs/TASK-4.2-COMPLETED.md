# Task 4.2: Tasks::UpdateStatus Interaction - COMPLETED

## Task Description
Create status update interaction with logging and broadcasting functionality for task status updates and debug log appending.

**Reference**: `docs/spec-orchestrator.md` (lines 75-81)

## Implementation Summary

### ✅ Completed Components

#### 1. Tasks::UpdateStatus Interaction Class
**File**: `app/interactions/tasks/update_status.rb`

**Features**:
- Updates task status with validation
- Appends log messages to debug_log with timestamps
- Updates PR URL when provided
- Broadcasts Turbo Stream updates to epic channel
- Wrapped in ActiveRecord transaction for safety
- Graceful error handling for broadcasting failures

**Interface**:
```ruby
Tasks::UpdateStatus.run!(
  task: task,                    # Required: Task object
  new_status: 'running',         # Required: Valid status string
  log_message: 'Message',        # Optional: Log entry
  pr_url: 'https://...'          # Optional: PR URL
)
```

**Valid Statuses**:
- `pending`
- `running`
- `pr_open`
- `merging`
- `completed`
- `failed`

#### 2. Comprehensive Test Suite
**File**: `spec/interactions/tasks/update_status_spec.rb`

**Test Coverage** (25+ tests):
- ✅ Basic status updates
- ✅ PR URL updates
- ✅ Log message appending with timestamps
- ✅ Multiple sequential log appends
- ✅ All valid status transitions
- ✅ Invalid status rejection
- ✅ Turbo Stream broadcasting
- ✅ Transaction rollback on errors
- ✅ Edge cases (nil, empty values)
- ✅ Log formatting and preservation
- ✅ Broadcast failure handling

#### 3. Console Test Script
**File**: `script/test_update_status_interaction.rb`

**Capabilities**:
- Creates test data (user, repo, epic, tasks)
- Tests all major use cases
- Validates error handling
- Tests workflow transitions
- Tests edge cases
- Provides detailed output and summary
- Cleans up test data

#### 4. Testing Documentation
**File**: `docs/TASK-4.2-TESTING.md`

**Contents**:
- Running RSpec tests
- Using console test script
- Manual console testing examples
- Validation rules
- Log format specification
- Broadcasting details
- Next steps for integration

## Key Implementation Details

### Log Appending with Timestamps
```ruby
def append_to_debug_log(message)
  timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
  log_entry = "[#{timestamp}] #{message}"
  
  current_log = task.debug_log.to_s
  updated_log = current_log.blank? ? log_entry : "#{current_log}\n#{log_entry}"
  
  task.update!(debug_log: updated_log)
end
```

### Turbo Stream Broadcasting
```ruby
def broadcast_task_update
  task.broadcast_replace_to(
    "epic_#{task.epic_id}",
    target: "task_#{task.id}",
    partial: "tasks/task",
    locals: { task: task }
  )
rescue => e
  # Log but don't fail transaction
  Rails.logger.error("Failed to broadcast task update: #{e.message}")
end
```

### Transaction Safety
All updates are wrapped in `ActiveRecord::Base.transaction` to ensure atomicity. If any update fails, all changes are rolled back.

## Usage Examples

### From Console
```ruby
# Basic status update
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running'
)

# With logging
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running',
  log_message: 'Starting Cursor agent...'
)

# Full update with PR
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'pr_open',
  log_message: 'PR created successfully',
  pr_url: 'https://github.com/user/repo/pull/123'
)
```

### From Jobs/Controllers
```ruby
# In Tasks::ExecuteJob
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'running',
  log_message: "Launching Cursor agent..."
)

# In Webhooks::CursorController
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'pr_open',
  log_message: "Agent finished, PR created.",
  pr_url: payload['target']['prUrl']
)

# In Tasks::MergeJob
Tasks::UpdateStatus.run!(
  task: task,
  new_status: 'completed',
  log_message: "Merge successful."
)
```

## Acceptance Criteria Met

✅ **Create Tasks::UpdateStatus interaction**
- Inputs: task, new_status, log_message (optional), pr_url (optional)
- Updates task.status to new_status
- Updates task.pr_url if provided
- Appends log_message to task.debug_log with timestamp
- Broadcasts Turbo Stream update to epic channel

✅ **Test task status updates**
- Comprehensive RSpec test suite with 25+ tests
- Console test script for manual validation
- All valid status transitions tested
- Invalid inputs properly rejected

✅ **Debug log appending**
- Logs append with timestamps in format: `[YYYY-MM-DD HH:MM:SS] message`
- Multiple log entries preserved (newline separated)
- Handles nil/empty debug_log gracefully
- Log content preserved exactly (special chars, multiline)

## Integration Points

This interaction is ready to be used by:

1. **Tasks::ExecuteJob** (Phase 5.1)
   - Update to 'running' when launching agent
   - Save agent ID and branch name

2. **Webhooks::CursorController** (Phase 5.2-5.3)
   - Update on webhook RUNNING events
   - Update to 'pr_open' on FINISHED with PR URL
   - Update to 'failed' on ERROR

3. **Tasks::MergeJob** (Phase 7)
   - Update to 'merging' when starting merge
   - Update to 'completed' on success
   - Update to 'failed' on conflict

4. **Epics::Start** (Phase 4.3)
   - Update first task status when starting epic

## Files Created/Modified

### Created
1. `app/interactions/tasks/update_status.rb` - Main interaction class
2. `spec/interactions/tasks/update_status_spec.rb` - Test suite
3. `script/test_update_status_interaction.rb` - Console test script
4. `docs/TASK-4.2-TESTING.md` - Testing documentation
5. `docs/TASK-4.2-COMPLETED.md` - This completion summary

### Dependencies
- ActiveInteraction gem (already in project)
- Task model (already implemented)
- Epic model (already implemented)
- Turbo Streams (for broadcasting)

## Testing Instructions

### Run RSpec Tests
```bash
bundle exec rspec spec/interactions/tasks/update_status_spec.rb -fd
```

### Run Console Script
```bash
rails runner script/test_update_status_interaction.rb
```

### Manual Console Testing
```bash
rails console
load 'script/test_update_status_interaction.rb'
```

## Next Steps

Continue with Phase 4:
- **Task 4.3**: Epics::Start Interaction
  - Start epic from console
  - Update epic status to 'running'
  - Enqueue Tasks::ExecuteJob for first task
  - Use Tasks::UpdateStatus to update first task

Then proceed to Phase 5:
- **Task 5.1**: Tasks::ExecuteJob
  - Use Tasks::UpdateStatus to mark task as running
  - Launch Cursor agent via CursorAgentService
  - Save agent ID and branch name

## Notes

- Database column is `pr_url` (not `pull_request_url`)
- Broadcasting errors are logged but don't fail the transaction
- All status values must match Task model enum values
- Log timestamps use `Time.current` for consistency with Rails
- Transaction ensures atomicity of all updates

## Completion Date
2025-10-29

## Status
✅ **COMPLETED** - All acceptance criteria met, tested, and documented.
