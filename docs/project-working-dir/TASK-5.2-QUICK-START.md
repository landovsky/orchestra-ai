# Task 5.2: Webhook Quick Start

## 🚀 Quick Test (5 minutes)

### 1. Create Test Task
```bash
bin/rails console
```

```ruby
user = User.first || User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
repo = Repository.create!(name: 'test-repo', github_url: 'https://github.com/test/repo', user: user)
epic = Epic.create!(title: 'Webhook Test', repository: repo, user: user, base_branch: 'main')
task = Task.create!(epic: epic, description: 'Test webhook', position: 1)
puts "Task ID: #{task.id}"
```

### 2. Start Server & Logs
Terminal 1:
```bash
bin/rails server
```

Terminal 2:
```bash
tail -f log/development.log | grep -A 20 "Webhook"
```

### 3. Send Test Webhook
Terminal 3:
```bash
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "RUNNING", "agent_id": "test_123"}'
```

### 4. Or Use Test Script
```bash
export TEST_TASK_ID=1
ruby script/test_webhook.rb
```

## ✅ Expected Result

You should see in logs:
```
================================================================================
[Webhook] Cursor callback received
--------------------------------------------------------------------------------
Task ID: 1
Task Description: Test webhook
Task Status: pending
--------------------------------------------------------------------------------
Payload:
{
  "status": "RUNNING",
  "agent_id": "test_123"
}
================================================================================
```

## 🌐 Test with ngrok

Terminal 1:
```bash
ngrok http 3000
```

Copy the https URL, then:
```bash
export WEBHOOK_BASE_URL=https://abc123.ngrok.io
ruby script/test_webhook.rb
```

## 📚 Full Documentation

- Complete guide: `docs/TASK-5.2-WEBHOOK-TESTING.md`
- Completion report: `docs/TASK-5.2-COMPLETED.md`

## 🎯 Success Criteria

- ✅ Can send webhook and get 200 response
- ✅ Logs show full webhook payload
- ✅ Works with RUNNING, FINISHED, ERROR statuses
