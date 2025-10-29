# Task 5.2: Webhook Controller - COMPLETED ✅

## Task Summary

Created a minimal webhook controller to receive Cursor agent status callbacks, with ngrok setup for testing.

## Date Completed
2025-10-29

## Deliverables

### 1. Webhook Controller (`app/controllers/webhooks_controller.rb`)
- ✅ Receives POST requests at `/webhooks/cursor/:task_id`
- ✅ Handles RUNNING, FINISHED, and ERROR statuses
- ✅ Comprehensive logging with full payload details
- ✅ Flexible payload parsing (supports multiple formats)
- ✅ Error handling for invalid tasks and payloads
- ✅ Returns appropriate HTTP status codes
- ✅ Skips CSRF protection (for external API callbacks)
- ✅ Skips authentication (minimal implementation)

### 2. Webhook Route (`config/routes.rb`)
- ✅ Added route: `POST /webhooks/cursor/:task_id`
- ✅ Maps to `webhooks#cursor` action
- ✅ Named route helper: `cursor_webhook_path`

### 3. Test Script (`script/test_webhook.rb`)
- ✅ Standalone Ruby script for testing webhooks
- ✅ Sends RUNNING status test payload
- ✅ Sends FINISHED status test payload (with PR URL)
- ✅ Sends ERROR status test payload
- ✅ Tests invalid task ID handling
- ✅ Tests invalid payload handling
- ✅ Configurable via environment variables
- ✅ Pretty-printed JSON output
- ✅ Executable permissions set

### 4. Testing Documentation (`docs/TASK-5.2-WEBHOOK-TESTING.md`)
- ✅ Complete ngrok installation guide
- ✅ Step-by-step setup instructions
- ✅ Test data creation examples
- ✅ Multiple testing methods (script, curl, real agent)
- ✅ Expected webhook flow documentation
- ✅ Troubleshooting guide
- ✅ Success criteria checklist

## Implementation Details

### Controller Features

**Endpoint**: `POST /webhooks/cursor/:task_id`

**Security Considerations**:
- CSRF protection disabled (external API)
- Devise authentication bypassed (if enabled)
- TODO for Phase 6+: Add webhook signature verification

**Logging**:
- Full payload logging with pretty-printed JSON
- Task context (ID, description, status)
- Separate error logging
- Timestamped entries

**Status Extraction**:
- Supports `status` parameter (direct)
- Supports `data.status` (nested)
- Supports `event` parameter (alternative)

**Error Responses**:
- 404: Task not found
- 400: Invalid payload (missing status)
- 500: Internal server error

**Success Response**:
```json
{
  "success": true,
  "task_id": 1,
  "status": "RUNNING"
}
```

### Route Details

```ruby
# config/routes.rb
post 'webhooks/cursor/:task_id', to: 'webhooks#cursor', as: :cursor_webhook
```

**URL Example**: `/webhooks/cursor/123`
**Helper**: `cursor_webhook_path(task_id)`

### Test Script Usage

```bash
# Local testing
export TEST_TASK_ID=1
ruby script/test_webhook.rb

# With ngrok
export WEBHOOK_BASE_URL=https://abc123.ngrok.io
export TEST_TASK_ID=1
ruby script/test_webhook.rb
```

## Testing Instructions

See `docs/TASK-5.2-WEBHOOK-TESTING.md` for complete testing guide.

### Quick Test

1. Start Rails server: `bin/rails server`
2. Create test task in console
3. Send test webhook:
```bash
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "RUNNING", "agent_id": "test_123"}'
```
4. Check logs: `tail -f log/development.log`

### Expected Log Output

```
================================================================================
[Webhook] Cursor callback received
--------------------------------------------------------------------------------
Task ID: 1
Task Description: Test task for webhook testing
Task Status: pending
--------------------------------------------------------------------------------
Payload:
{
  "status": "RUNNING",
  "agent_id": "bc_test_123",
  "timestamp": "2025-10-29T10:00:00Z",
  "message": "Agent started processing task"
}
================================================================================
[Webhook] Task 1: Received RUNNING status
```

## Acceptance Criteria

✅ **AC1**: Controller receives and logs webhook payloads  
✅ **AC2**: Can receive RUNNING status  
✅ **AC3**: Can receive FINISHED status  
✅ **AC4**: Can receive ERROR status  
✅ **AC5**: ngrok setup documented  
✅ **AC6**: Webhook testing documented  
✅ **AC7**: Test script provided  

## Files Changed/Created

### New Files
1. `app/controllers/webhooks_controller.rb` - Webhook controller
2. `script/test_webhook.rb` - Test script
3. `docs/TASK-5.2-WEBHOOK-TESTING.md` - Testing documentation
4. `docs/TASK-5.2-COMPLETED.md` - This file

### Modified Files
1. `config/routes.rb` - Added webhook route

## Integration with Task Execution

The webhook URL is used in Task 5.1 (Tasks::ExecuteJob):

```ruby
# When launching Cursor agent
webhook_url = "https://your-domain.com/webhooks/cursor/#{task.id}"

cursor_service.launch_agent(
  task: task,
  webhook_url: webhook_url,
  branch_name: branch_name
)
```

Cursor agent will POST status updates to this URL as it:
1. Starts executing (RUNNING)
2. Completes successfully (FINISHED)
3. Encounters errors (ERROR)

## Next Steps

### Task 5.3: Webhook FINISHED Handler
- Implement status transition logic
- Update task status to `pr_open` on FINISHED
- Save PR URL from webhook payload
- Trigger next task in sequence (if applicable)
- Handle ERROR status (mark task as failed)

### Future Enhancements (Phase 6+)
- Add webhook signature verification (WEBHOOK_SECRET)
- Add rate limiting
- Add webhook event logging table
- Add retry mechanism for failed webhook processing
- Add async webhook processing (background job)

## Notes

**Current Implementation**: Minimal - logs webhooks but doesn't process them

**Design Decision**: Keep it simple for now
- Just receive and log payloads
- Verify webhook connection works
- Test with real Cursor agent
- Add status processing in Task 5.3

**Security Note**: No authentication/verification yet
- Acceptable for development/testing
- Must add signature verification before production
- Use CURSOR_WEBHOOK_SECRET environment variable

**Testing Approach**: Console-first
- Manual testing with curl/script
- Real webhook testing with ngrok
- Visual verification via log tailing
- No automated tests yet (Phase 6+)

## Console Testing Example

```ruby
# 1. Create test data
user = User.first || User.create!(email: 'test@test.com', password: 'password')
repo = Repository.create!(name: 'test', github_url: 'https://github.com/test/repo', user: user)
epic = Epic.create!(title: 'Test', repository: repo, user: user, base_branch: 'main')
task = Task.create!(epic: epic, description: 'Test webhook', position: 1)

# 2. Start ngrok in another terminal
# ngrok http 3000

# 3. Test webhook manually
# curl -X POST https://your-ngrok-url.ngrok.io/webhooks/cursor/1 \
#   -H "Content-Type: application/json" \
#   -d '{"status": "RUNNING", "agent_id": "test"}'

# 4. Check logs
# tail -f log/development.log

# 5. Or use test script
# export WEBHOOK_BASE_URL=https://your-ngrok-url.ngrok.io
# export TEST_TASK_ID=1
# ruby script/test_webhook.rb
```

## Success Verification

To verify Task 5.2 is complete:

1. ✅ Controller file exists and has no syntax errors
2. ✅ Route is configured correctly
3. ✅ Can send webhook via curl and get 200 response
4. ✅ Logs show detailed webhook payload
5. ✅ Can distinguish RUNNING, FINISHED, ERROR statuses
6. ✅ Test script runs successfully
7. ✅ Documentation is complete and clear

## Status

**COMPLETED** ✅

Ready to proceed to Task 5.3: Webhook FINISHED Handler
