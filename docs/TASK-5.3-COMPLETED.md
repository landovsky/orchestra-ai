# Task 5.3: Webhook FINISHED Handler - COMPLETED ✓

## Summary

Implemented a comprehensive webhook handler for the FINISHED status that transitions tasks to `pr_open` state and saves the PR URL.

## Changes Made

### 1. Updated WebhooksController (`app/controllers/webhooks_controller.rb`)

Added three handler methods for different webhook statuses:

#### `handle_finished_status(task, params)`
- Extracts PR URL from webhook payload (supports multiple formats)
- Transitions task to `pr_open` status
- Saves PR URL to task
- Appends log message with PR URL

#### `handle_running_status(task, params)`
- Transitions pending tasks to `running` status
- Skips update if task is already beyond running state
- Appends log message

#### `handle_error_status(task, params)`
- Extracts error message from payload
- Transitions task to `failed` status
- Appends error details to log

#### Helper Methods
- `extract_pr_url(params)` - Supports multiple PR URL formats:
  - `target.prUrl` (Cursor API format)
  - `target.pr_url` (alternate format)
  - `pr_url` (direct parameter)
  - `prUrl` (direct parameter)
  - `data.pr_url` (nested data format)
  - `data.prUrl` (nested data format)

- `extract_error_message(params)` - Extracts error messages from various fields:
  - `error_message`
  - `error`
  - `data.error`
  - `message`

### 2. Created Comprehensive Test Suite (`spec/controllers/webhooks_controller_spec.rb`)

**Test Coverage:**
- ✓ FINISHED status transitions task to pr_open
- ✓ FINISHED status saves PR URL
- ✓ FINISHED status appends log message
- ✓ Multiple PR URL format support (prUrl, pr_url, direct)
- ✓ FINISHED without PR URL (graceful handling)
- ✓ RUNNING status transitions pending tasks
- ✓ RUNNING status doesn't affect tasks past running
- ✓ ERROR status transitions to failed
- ✓ ERROR message extraction from multiple formats
- ✓ Case insensitive status handling
- ✓ Task not found (404 error)
- ✓ Invalid payload (400 error)
- ✓ Unknown status (graceful handling)
- ✓ Nested data structure support
- ✓ Exception handling (500 error)

**Total: 20+ test cases**

### 3. Created Console Test Script (`script/test_webhook_finished.rb`)

Interactive test script that:
- Creates test data (user, epic, tasks)
- Simulates FINISHED webhooks with various payloads
- Tests PR URL extraction from multiple formats
- Tests RUNNING and ERROR webhooks
- Displays full task state after updates
- Shows integration flow example

## Testing Instructions

### Option 1: Run RSpec Tests

```bash
cd /workspace
bundle exec rspec spec/controllers/webhooks_controller_spec.rb --format documentation
```

Expected output: All 20+ tests should pass ✓

### Option 2: Run Console Test Script

```bash
cd /workspace
rails runner script/test_webhook_finished.rb
```

Or from Rails console:
```ruby
load 'script/test_webhook_finished.rb'
```

Expected output:
```
================================================================================
Testing Webhook FINISHED Handler (Task 5.3)
================================================================================

1. Creating test data...
   ✓ Created user: webhook-test@example.com
   ✓ Created epic: Test Epic for Webhook FINISHED Handler
   ✓ Created task: Test task for webhook FINISHED handler
   ✓ Task ID: 1
   ✓ Initial status: running

2. Testing FINISHED webhook with PR URL (prUrl format)...
   ✓ Status updated to: pr_open
   ✓ PR URL saved: https://github.com/test/webhook-repo/pull/123
   ✓ Log message: [timestamp] Cursor agent finished. PR created: https://...

... (more tests)

================================================================================
ALL WEBHOOK TESTS PASSED! ✓
================================================================================
```

### Option 3: Manual Webhook Testing with ngrok

1. Start Rails server:
```bash
rails server
```

2. Start ngrok in another terminal:
```bash
ngrok http 3000
```

3. Launch Cursor agent with webhook URL:
```ruby
task = Task.first
cursor_service = Services::CursorAgentService.new(cursor_credential)
cursor_service.launch_agent(
  task: task,
  webhook_url: "https://your-ngrok-url.ngrok.io/webhooks/cursor/#{task.id}",
  branch_name: "test-branch"
)
```

4. Watch logs:
```bash
tail -f log/development.log | grep Webhook
```

5. Verify task state after webhook:
```ruby
task.reload
task.status        # => "pr_open"
task.pr_url        # => "https://github.com/..."
task.debug_log     # => Shows webhook message
```

## Acceptance Criteria ✓

All acceptance criteria from Task 5.3 have been met:

- ✅ Task transitions from `running` to `pr_open` when FINISHED webhook received
- ✅ PR URL is extracted and saved to `task.pr_url`
- ✅ Log message appended to `task.debug_log`
- ✅ Handles multiple PR URL formats
- ✅ Gracefully handles missing PR URL
- ✅ Also implemented RUNNING and ERROR handlers (bonus)
- ✅ Comprehensive test coverage
- ✅ Console test script for manual verification

## Example Webhook Payloads

### FINISHED with PR URL (Cursor format)
```json
{
  "status": "FINISHED",
  "target": {
    "prUrl": "https://github.com/user/repo/pull/123"
  }
}
```

### FINISHED with alternate format
```json
{
  "status": "FINISHED",
  "pr_url": "https://github.com/user/repo/pull/123"
}
```

### RUNNING
```json
{
  "status": "RUNNING"
}
```

### ERROR with message
```json
{
  "status": "ERROR",
  "error_message": "Agent failed due to syntax error"
}
```

## Integration Flow

```
1. Task.status = :pending
   ↓
2. Tasks::ExecuteJob runs
   → Launches Cursor agent
   → Task.status = :running
   → Saves agent_id and branch_name
   ↓
3. Webhook: RUNNING received
   → Updates status (if still pending)
   → Logs: "Cursor agent is now running"
   ↓
4. Webhook: FINISHED received ✓ (THIS TASK)
   → Task.status = :pr_open
   → Task.pr_url = "https://github.com/..."
   → Logs: "Cursor agent finished. PR created: ..."
   ↓
5. Tasks::MergeJob (next phase)
   → Merges PR
   → Task.status = :completed
   → Starts next task
```

## Files Modified/Created

1. **Modified:** `app/controllers/webhooks_controller.rb`
   - Added handler methods for FINISHED, RUNNING, ERROR
   - Added helper methods for payload extraction

2. **Created:** `spec/controllers/webhooks_controller_spec.rb`
   - 20+ comprehensive test cases
   - Tests all webhook scenarios

3. **Created:** `script/test_webhook_finished.rb`
   - Console test script
   - Manual verification tool

4. **Created:** `docs/TASK-5.3-COMPLETED.md`
   - This documentation file

## Next Steps (Phase 7)

Task 5.3 is complete. Ready for Phase 7:

- **Task 7.1:** Implement Tasks::MergeJob to merge PRs
- **Task 7.2:** Add sequential task orchestration
- **Task 7.3:** Handle epic completion
- **Task 7.4:** Enhance ERROR webhook handler with epic pause

## Notes

- The webhook controller now handles all three main statuses: RUNNING, FINISHED, ERROR
- PR URL extraction is flexible and handles multiple payload formats
- Task status transitions use the existing `Tasks::UpdateStatus` interaction
- All changes are backward compatible
- Comprehensive logging for debugging
- Error handling is robust with fallbacks

---

**Status:** ✅ COMPLETED  
**Date:** 2025-10-29  
**Phase:** 5 (Task Execution Engine)  
**Next Task:** 7.1 (Tasks::MergeJob)
