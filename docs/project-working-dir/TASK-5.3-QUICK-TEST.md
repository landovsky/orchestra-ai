# Task 5.3: Quick Testing Guide

## Quick Console Test (2 minutes)

```ruby
# 1. Create test task
user = User.first
repo = user.repositories.first
epic = Epic.create!(user: user, repository: repo, title: "Test", base_branch: "main")
task = Task.create!(epic: epic, description: "Test webhook", position: 0, status: :running)

# 2. Simulate FINISHED webhook
outcome = Tasks::UpdateStatus.run(
  task: task,
  new_status: 'pr_open',
  pr_url: 'https://github.com/test/repo/pull/123',
  log_message: 'Cursor agent finished. PR created: https://github.com/test/repo/pull/123'
)

# 3. Verify results
task.reload
task.status        # Should be: "pr_open"
task.pr_url        # Should be: "https://github.com/test/repo/pull/123"
puts task.debug_log  # Should show: "Cursor agent finished. PR created: ..."
```

## Quick RSpec Test (30 seconds)

```bash
bundle exec rspec spec/controllers/webhooks_controller_spec.rb
```

Expected: 20+ examples, 0 failures

## Quick HTTP Test (with curl)

```bash
# Start Rails server
rails server

# In another terminal, send test webhook:
curl -X POST http://localhost:3000/webhooks/cursor/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "FINISHED",
    "target": {
      "prUrl": "https://github.com/test/repo/pull/123"
    }
  }'

# Should return:
# {"success":true,"task_id":1,"status":"FINISHED"}
```

## Key Test Points

✓ Task transitions to `pr_open`  
✓ PR URL is saved  
✓ Log message is appended  
✓ Handles missing PR URL gracefully  
✓ Supports multiple PR URL formats  

## Integration Test Scenario

```ruby
# Full workflow simulation
task = Task.create!(epic: epic, description: "Feature X", position: 0, status: :pending)

# 1. Job launches agent
task.update!(status: :running, cursor_agent_id: 'agent_123', branch_name: 'cursor/feature-x')

# 2. Webhook RUNNING (optional)
Tasks::UpdateStatus.run(task: task, new_status: 'running', log_message: 'Agent running')

# 3. Webhook FINISHED (THIS TASK)
Tasks::UpdateStatus.run(
  task: task,
  new_status: 'pr_open',
  pr_url: 'https://github.com/user/repo/pull/42',
  log_message: 'Cursor agent finished. PR created: https://github.com/user/repo/pull/42'
)

# 4. Verify
task.reload.status  # => "pr_open"
task.pr_url         # => "https://github.com/user/repo/pull/42"

# Next: MergeJob will merge this PR and start next task
```

## Expected Controller Flow

```
POST /webhooks/cursor/:task_id
  ↓
Extract status from payload
  ↓
Case status.upcase
  when 'FINISHED' → handle_finished_status
  when 'RUNNING'  → handle_running_status  
  when 'ERROR'    → handle_error_status
  ↓
Update task via Tasks::UpdateStatus interaction
  ↓
Return JSON: { success: true, task_id: X, status: "FINISHED" }
```

## Payload Format Examples

### Standard (Cursor API)
```json
{ "status": "FINISHED", "target": { "prUrl": "https://..." } }
```

### Alternate
```json
{ "status": "FINISHED", "pr_url": "https://..." }
```

### Without PR URL
```json
{ "status": "FINISHED" }
```
Still transitions to `pr_open`, pr_url remains nil, log shows "URL not provided"

---

**All tests should pass without errors!**
