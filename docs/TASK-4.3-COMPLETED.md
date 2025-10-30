# Task 4.3: Epics::Start Interaction - COMPLETED

## Task Description
Create interaction to start epic manually from console. Test epic status changes and first task job enqueuing.

**Reference**: `docs/spec-orchestrator.md` (lines 67-74) and `docs/implementation-tasks.md` (lines 99-108)

## Implementation Summary

### ✅ Completed Components

#### 1. Epics::Start Interaction Class
**File**: `app/interactions/epics/start.rb`

**Features**:
- Validates epic is in pending status before starting
- Validates epic belongs to the user
- Validates epic has at least one task
- Updates epic status from 'pending' to 'running'
- Finds first pending task (by position order)
- Enqueues Tasks::ExecuteJob for the first pending task
- Broadcasts Turbo Stream updates to epic channel
- Wrapped in ActiveRecord transaction for safety
- Graceful error handling for broadcasting failures

**Interface**:
```ruby
Epics::Start.run!(
  user: user,      # Required: User object who owns the epic
  epic: epic       # Required: Epic object to start
)
```

**Validations**:
- Epic must be in 'pending' status (not running, completed, failed, paused, or generating_spec)
- Epic must belong to the specified user
- Epic must have at least one task

**Behavior**:
- Changes epic status to 'running'
- Finds the first pending task ordered by position (ascending)
- Enqueues Tasks::ExecuteJob.perform_async(task.id)
- If no pending tasks exist, epic is still set to running but no job is enqueued
- Returns the updated epic object

#### 2. Tasks::ExecuteJob Stub
**File**: `app/jobs/tasks/execute_job.rb`

**Purpose**:
- Stub implementation for Task 4.3 testing
- Logs when job is enqueued
- Will be fully implemented in Phase 5.1

**Future Implementation** (Phase 5.1):
1. Call Tasks::UpdateStatus to mark task as 'running'
2. Generate branch_name
3. Generate webhook_url
4. Call CursorAgentService.launch_agent
5. Update task with cursor_agent_id and branch_name

#### 3. Comprehensive Test Suite
**File**: `spec/interactions/epics/start_spec.rb`

**Test Coverage** (25+ tests):
- ✅ Basic epic status updates
- ✅ Job enqueuing for first pending task
- ✅ Task position ordering (lowest position first)
- ✅ Handling completed/failed tasks (skip to next pending)
- ✅ Turbo Stream broadcasting
- ✅ Broadcast failure handling (doesn't break transaction)
- ✅ Transaction rollback on errors
- ✅ Invalid status rejection (running, completed, failed, paused, generating_spec)
- ✅ User ownership validation
- ✅ Epic must have tasks validation
- ✅ Epic with no pending tasks (updates to running, no job enqueued)
- ✅ Multiple epics independence
- ✅ Required parameters validation
- ✅ Edge cases (single task, many tasks, out-of-order positions)

#### 4. Console Test Script
**File**: `script/test_start_epic_interaction.rb`

**Capabilities**:
- Creates complete test data (user, credentials, repository, epic, tasks)
- Tests all major use cases
- Tests error handling scenarios
- Tests task ordering by position
- Tests multiple epics independence
- Provides detailed output with pass/fail indicators
- Cleans up test data automatically

**Test Cases**:
1. Basic epic start functionality
2. Epic status changes to running
3. Job enqueuing for first task
4. Error: Already running epic
5. Error: Epic without tasks
6. Error: Wrong user ownership
7. Epic with all completed tasks (no pending)
8. Task position ordering
9. Multiple epics independence

#### 5. Documentation
**File**: `docs/TASK-4.3-COMPLETED.md`

**Contents**:
- Implementation summary
- Usage examples
- Testing instructions
- Integration points
- Validation rules
- Next steps

## Key Implementation Details

### Epic Status Validation
```ruby
def validate_epic_is_pending
  unless epic&.pending?
    errors.add(:epic, 'must be in pending status to start')
  end
end
```

### User Ownership Validation
```ruby
def validate_epic_belongs_to_user
  unless epic&.user_id == user&.id
    errors.add(:epic, 'must belong to the user')
  end
end
```

### Task Has Tasks Validation
```ruby
def validate_epic_has_tasks
  if epic && epic.tasks.empty?
    errors.add(:epic, 'must have at least one task')
  end
end
```

### Finding First Pending Task by Position
```ruby
first_task = epic.tasks.where(status: :pending).order(position: :asc).first
```

### Job Enqueuing
```ruby
if first_task
  Tasks::ExecuteJob.perform_async(first_task.id)
  broadcast_epic_update
end
```

### Turbo Stream Broadcasting
```ruby
def broadcast_epic_update
  epic.broadcast_replace_to(
    "epic_#{epic.id}",
    target: "epic_#{epic.id}",
    partial: "epics/epic",
    locals: { epic: epic }
  )
rescue => e
  Rails.logger.error("Failed to broadcast epic update: #{e.message}")
end
```

### Transaction Safety
All updates are wrapped in `ActiveRecord::Base.transaction` to ensure atomicity. If job enqueuing or any update fails, all changes are rolled back.

## Usage Examples

### From Console
```ruby
# Create epic with tasks using CreateFromManualSpec
tasks_json = [
  'Task 1: Setup database',
  'Task 2: Create API endpoints', 
  'Task 3: Write tests'
].to_json

result = Epics::CreateFromManualSpec.run!(
  user: user,
  repository: repo,
  tasks_json: tasks_json,
  base_branch: 'main',
  cursor_agent_credential_id: cursor_cred.id
)

epic = result[:epic]

# Start the epic
outcome = Epics::Start.run!(user: user, epic: epic)

# Check results
epic.reload.status          # => 'running'
epic.tasks.first.status     # => 'pending' (job enqueued but not run yet)
```

### With Error Handling
```ruby
outcome = Epics::Start.run(user: user, epic: epic)

if outcome.valid?
  puts "Epic started successfully!"
  puts "Epic status: #{epic.reload.status}"
else
  puts "Failed to start epic:"
  outcome.errors.full_messages.each do |msg|
    puts "  - #{msg}"
  end
end
```

### Check If Can Be Started
```ruby
def can_start_epic?(user, epic)
  return false unless epic.pending?
  return false unless epic.user_id == user.id
  return false unless epic.tasks.any?
  true
end
```

## Acceptance Criteria Met

✅ **Create Epics::Start interaction**
- Inputs: user, epic
- Validates epic is pending
- Sets epic.status to running
- Finds the first pending Task
- Enqueues Tasks::ExecuteJob.perform_async(task.id)
- Broadcasts update via Turbo Streams

✅ **Test epic status changes**
- Epic transitions from 'pending' to 'running'
- Invalid status transitions rejected
- Transaction rollback on errors
- Multiple epics can be started independently

✅ **Test first task job enqueuing**
- Job enqueued for first pending task (by position)
- Correct task ID passed to job
- No job enqueued if no pending tasks
- Job enqueuing errors cause transaction rollback

## Integration Points

This interaction is ready to be integrated with:

1. **EpicsController#start** (Phase 6.4)
   - POST /epics/:id/start
   - Button click → Epics::Start → Redirect
   - Will use this interaction to start epics from UI

2. **Tasks::ExecuteJob** (Phase 5.1)
   - Currently stub implementation
   - Will be enhanced to actually launch Cursor agents
   - This interaction enqueues that job

3. **Tasks::MergeJob** (Phase 7.2)
   - After task completes, finds next pending task
   - May need similar logic to find and enqueue next task
   - Can reference this interaction's task-finding logic

4. **Dashboard UI** (Phase 8)
   - Broadcasting enables real-time updates
   - Epic status changes appear automatically
   - No manual refresh needed

## Workflow Integration

### Current Epic Lifecycle
1. **Create Epic** → Epics::CreateFromManualSpec
   - Creates epic with status 'pending'
   - Creates tasks with status 'pending'
   
2. **Start Epic** → Epics::Start (THIS INTERACTION) ✅
   - Changes epic to 'running'
   - Enqueues Tasks::ExecuteJob for first task
   
3. **Execute Task** → Tasks::ExecuteJob (Phase 5.1)
   - Launches Cursor agent
   - Waits for webhook callbacks
   
4. **Complete Task** → Tasks::MergeJob (Phase 7)
   - Merges PR
   - Enqueues next task or completes epic

## Files Created/Modified

### Created
1. `app/interactions/epics/start.rb` - Main interaction class
2. `app/jobs/tasks/execute_job.rb` - Stub job for testing
3. `spec/interactions/epics/start_spec.rb` - Comprehensive test suite
4. `script/test_start_epic_interaction.rb` - Console test script
5. `docs/TASK-4.3-COMPLETED.md` - This completion summary

### Dependencies
- ActiveInteraction gem (already in project)
- Epic model (already implemented)
- Task model (already implemented)
- Tasks::UpdateStatus interaction (implemented in Task 4.2)
- Turbo Streams (for broadcasting)
- Sidekiq (for job enqueuing)

## Testing Instructions

### Run RSpec Tests
```bash
bundle exec rspec spec/interactions/epics/start_spec.rb -fd
```

### Run Console Script
```bash
rails runner script/test_start_epic_interaction.rb
```

### Manual Console Testing
```bash
rails console
```

Then run:
```ruby
# Setup
user = User.first
repo = Repository.first

tasks_json = ['Task 1: Do X', 'Task 2: Do Y'].to_json

result = Epics::CreateFromManualSpec.run!(
  user: user,
  repository: repo,
  tasks_json: tasks_json,
  base_branch: 'main'
)

epic = result[:epic]

# Test starting epic
Epics::Start.run!(user: user, epic: epic)

# Verify
epic.reload.status  # => 'running'

# Try to start again (should fail)
Epics::Start.run(user: user, epic: epic)
# => Should have validation error
```

## Validation Rules

### Epic Status
- ✅ `pending` - Can be started
- ❌ `running` - Cannot be started (already running)
- ❌ `completed` - Cannot be started (already done)
- ❌ `failed` - Cannot be started (requires manual intervention)
- ❌ `paused` - Cannot be started (requires manual resume)
- ❌ `generating_spec` - Cannot be started (not ready yet)

### User Ownership
- Epic must belong to the user starting it
- Prevents unauthorized epic manipulation

### Task Requirements
- Epic must have at least one task
- Prevents starting empty epics
- If all tasks are completed, epic can still be set to running (edge case)

## Next Steps

Continue with Phase 5:

### Task 5.1: Tasks::ExecuteJob Implementation
- Replace stub with full implementation
- Use Tasks::UpdateStatus to mark task as 'running'
- Generate branch_name: `"cursor-agent/task-#{task.id}-#{SecureRandom.hex(4)}"`
- Generate webhook_url: `"https://your-app.com/webhooks/cursor/#{task.id}"`
- Call CursorAgentService.launch_agent
- Save cursor_agent_id and branch_name to task

### Task 5.2: Webhook Controller
- Receive Cursor agent callbacks
- Handle RUNNING, FINISHED, ERROR statuses
- Update task status accordingly

### Task 5.3: End-to-End Testing
- Test full flow: Create → Start → Execute → Webhook → Complete
- Verify sequential task execution
- Test error handling

## Notes

- Interaction uses Sidekiq's `perform_async` for background job enqueuing
- Broadcasting is optional - failures are logged but don't break the transaction
- Task ordering is by position field (not creation order or ID)
- If no pending tasks exist, epic is still set to running (allows resuming paused epics)
- Transaction ensures atomicity of status update and job enqueuing

## Completion Date
2025-10-29

## Status
✅ **COMPLETED** - All acceptance criteria met, tested, and documented.
