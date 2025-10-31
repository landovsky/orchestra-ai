# Task 5.2: Webhook Controller Testing Guide

## Overview

This guide shows how to test the webhook controller that receives Cursor agent status updates.

## Prerequisites

- Rails server running on port 3000
- ngrok installed (for exposing local server to internet)
- Test task created in database

## Step 1: Install ngrok

### macOS (using Homebrew)
```bash
brew install ngrok
```

### Linux
```bash
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list && \
  sudo apt update && sudo apt install ngrok
```

### Manual Download
Download from: https://ngrok.com/download

## Step 2: Setup Test Data

Start Rails console and create test data:

```bash
bin/rails console
```

```ruby
# Create test user
user = User.first || User.create!(
  email: 'test@example.com', 
  password: 'password123',
  password_confirmation: 'password123'
)

# Create test repository
repo = Repository.create!(
  name: 'test-repo',
  github_url: 'https://github.com/test/repo',
  user: user
)

# Create test epic
epic = Epic.create!(
  title: 'Test Epic for Webhook',
  repository: repo,
  user: user,
  base_branch: 'main'
)

# Create test task
task = Task.create!(
  epic: epic,
  description: 'Test task for webhook testing',
  position: 1
)

puts "Task ID: #{task.id}"
# => Task ID: 1 (use this ID for testing)
```

## Step 3: Start Rails Server

In one terminal window:

```bash
bin/rails server
```

Server should start on `http://localhost:3000`

## Step 4: Start ngrok

In a second terminal window:

```bash
ngrok http 3000
```

You should see output like:

```
ngrok                                                           (Ctrl+C to quit)

Session Status                online
Account                       Your Name (Plan: Free)
Version                       3.x.x
Region                        United States (us)
Latency                       -
Web Interface                 http://127.0.0.1:4040
Forwarding                    https://abc123.ngrok.io -> http://localhost:3000

Connections                   ttl     opn     rt1     rt5     p50     p90
                              0       0       0.00    0.00    0.00    0.00
```

Copy the `https://` forwarding URL (e.g., `https://abc123.ngrok.io`)

## Step 5: Watch Webhook Logs

In a third terminal window:

```bash
tail -f log/development.log
```

This will show webhook activity in real-time.

## Step 6: Test Webhook Locally

Using the test script (without ngrok):

```bash
# Set the task ID from Step 2
export TEST_TASK_ID=1

# Run the test script
ruby script/test_webhook.rb
```

This will send test webhooks to your local server and you should see:
1. Test script output showing payloads being sent
2. Log output showing webhook received
3. Rails server logs showing POST requests

## Step 7: Test with curl

You can also test manually with curl:

### Test RUNNING status
```bash
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "RUNNING",
    "agent_id": "bc_test_123",
    "timestamp": "2025-10-29T10:00:00Z",
    "message": "Agent started processing"
  }'
```

### Test FINISHED status
```bash
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "FINISHED",
    "agent_id": "bc_test_123",
    "timestamp": "2025-10-29T10:05:00Z",
    "target": {
      "prUrl": "https://github.com/test/repo/pull/123",
      "branch": "cursor-agent/task-1-test"
    },
    "message": "Agent completed successfully"
  }'
```

### Test ERROR status
```bash
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "ERROR",
    "agent_id": "bc_test_123",
    "timestamp": "2025-10-29T10:03:00Z",
    "error": {
      "code": "EXECUTION_FAILED",
      "message": "Failed to execute task"
    },
    "message": "Agent encountered an error"
  }'
```

## Step 8: Test with ngrok URL

To test with the ngrok URL (simulating external Cursor API):

```bash
# Use your ngrok URL from Step 4
export WEBHOOK_BASE_URL=https://abc123.ngrok.io
export TEST_TASK_ID=1

ruby script/test_webhook.rb
```

Or with curl:

```bash
curl -X POST https://abc123.ngrok.io/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "RUNNING",
    "agent_id": "bc_test_123",
    "timestamp": "2025-10-29T10:00:00Z"
  }'
```

## Step 9: Verify Webhook Logs

Check the log output (from Step 5). You should see:

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
  "message": "Agent started processing"
}
================================================================================
[Webhook] Task 1: Received RUNNING status
```

## Step 10: Test with Real Cursor Agent

To test with a real Cursor agent launch:

```ruby
# In Rails console
task = Task.find(1)

# Get ngrok URL
ngrok_url = "https://abc123.ngrok.io"  # Your ngrok URL
webhook_url = "#{ngrok_url}/webhooks/cursor/#{task.id}"

# Get Cursor credential
cursor_cred = Credential.find_by(service_name: 'cursor_agent')

# Launch agent
cursor_service = Services::CursorAgentService.new(cursor_cred)
result = cursor_service.launch_agent(
  task: task,
  webhook_url: webhook_url,
  branch_name: "test-webhook-#{Time.now.to_i}"
)

puts "Agent launched: #{result['id']}"
puts "Webhook URL: #{webhook_url}"
puts "Watch the logs for webhook callbacks..."
```

## Expected Webhook Flow

When a Cursor agent runs, you should receive webhooks in this order:

1. **RUNNING** - Agent starts executing the task
2. **FINISHED** or **ERROR** - Agent completes (success or failure)

## Webhook Endpoint Details

- **URL Pattern**: `/webhooks/cursor/:task_id`
- **Method**: POST
- **Content-Type**: application/json
- **Authentication**: None (for now)

### Expected Payload Format

```json
{
  "status": "RUNNING|FINISHED|ERROR",
  "agent_id": "bc_abc123",
  "timestamp": "2025-10-29T10:00:00Z",
  "target": {
    "prUrl": "https://github.com/user/repo/pull/123",
    "branch": "cursor-agent/task-1-abc"
  },
  "error": {
    "code": "ERROR_CODE",
    "message": "Error details"
  },
  "message": "Human readable message"
}
```

## Troubleshooting

### Webhook not receiving requests
- Check Rails server is running on port 3000
- Verify ngrok is forwarding to correct port
- Check firewall settings
- Verify task ID exists in database

### Webhook returns 404
- Check routes: `bin/rails routes | grep webhook`
- Verify controller file exists: `app/controllers/webhooks_controller.rb`

### Webhook returns 422 (CSRF error)
- This should not happen - controller has `skip_before_action :verify_authenticity_token`
- Check if Devise authentication is interfering

### No logs appearing
- Verify you're tailing the correct log file
- Check Rails.logger.level in `config/environments/development.rb`
- Try restarting Rails server

## Success Criteria

✅ Controller receives webhook POST requests  
✅ Webhook logs show full payload details  
✅ Can receive RUNNING status  
✅ Can receive FINISHED status  
✅ Can receive ERROR status  
✅ Returns appropriate HTTP status codes  
✅ Works with both local and ngrok URLs  

## Next Steps

After webhook controller is working:
- Task 5.3: Implement webhook FINISHED handler
- Handle status transitions (RUNNING → pr_open)
- Save PR URLs from FINISHED webhooks
- Trigger next task in sequence
