# Example Output: Cursor Service Console Validation

This document shows expected output when running the Cursor service validation script.

## Automated Script Output

```bash
$ export CURSOR_KEY=sk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ export TEST_WEBHOOK_URL=https://abc123.ngrok.io  # Optional
$ rails runner script/test_cursor_service.rb
```

### Expected Output (Success):

```
================================================================================
Cursor Service Console Validation
Task 3.2: Testing Cursor Agent Launch with API Credentials
================================================================================

Step 1: Validating environment setup
--------------------------------------------------------------------------------
✓ CURSOR_KEY found
✓ GITHUB_TOKEN found
✓ TEST_WEBHOOK_URL found: https://abc123.ngrok.io

Step 2: Setting up test user
--------------------------------------------------------------------------------
✓ Using existing user: test@example.com

Step 3: Setting up credentials
--------------------------------------------------------------------------------
Creating GitHub credential...
✓ Created GitHub credential
Creating Cursor credential...
✓ Created Cursor credential

Step 4: Setting up test repository
--------------------------------------------------------------------------------
Creating test repository...
✓ Created repository: test-orchestra-ai
  GitHub URL: https://github.com/landovsky/orchestra-ai

Step 5: Setting up test epic and task
--------------------------------------------------------------------------------
✓ Created test epic: Test Epic - Cursor Launch 1730229600
  Base branch: main
✓ Created test task (ID: 42)
  Description: Add comment to README explaining the purpose of this repository

Step 6: Initializing Cursor service
--------------------------------------------------------------------------------
✓ Cursor service initialized successfully
  API Endpoint: https://api.cursor.com/v0/agents
  Credential ID: 5

================================================================================
Step 7: Testing launch_agent method
================================================================================

Launch parameters:
  Task ID: 42
  Task Description: Add comment to README explaining the purpose of this repository
  Repository: https://github.com/landovsky/orchestra-ai
  Base Branch: main
  Target Branch: test-cursor-agent-1730229600
  Webhook URL: https://abc123.ngrok.io/webhooks/cursor/42

Launching Cursor agent...
--------------------------------------------------------------------------------
✓ SUCCESS: Agent launched successfully!

Response from Cursor API:
{
  "id": "bc_abc123xyz789def456ghi012jkl345",
  "status": "RUNNING",
  "createdAt": "2025-10-29T20:00:00.123Z",
  "prompt": {
    "text": "Add comment to README explaining the purpose of this repository"
  },
  "source": {
    "repository": "https://github.com/landovsky/orchestra-ai",
    "ref": "main"
  },
  "target": {
    "branchName": "test-cursor-agent-1730229600",
    "autoCreatePr": true
  }
}

✓ Agent ID: bc_abc123xyz789def456ghi012jkl345

You can now monitor this agent:
  - Check Cursor dashboard for agent status
  - Monitor webhook callbacks (if TEST_WEBHOOK_URL is set)
  - Watch for PR creation on GitHub

================================================================================
Step 8: Testing error handling and validation
================================================================================

Test 1: Launch with nil task
✓ Correctly raised ArgumentError: Task cannot be nil

Test 2: Launch with blank webhook URL
✓ Correctly raised ArgumentError: webhook_url cannot be blank

Test 3: Launch with blank branch name
✓ Correctly raised ArgumentError: branch_name cannot be blank

Test 4: Launch with task missing description
✓ Correctly raised ArgumentError: Task must have a description

================================================================================
Validation Complete
================================================================================

✅ ACCEPTANCE CRITERIA MET
   ✓ Can launch Cursor agent with real API credentials
   ✓ Agent ID returned from API
   ✓ Webhook URL configured
   ✓ Error handling validated

📋 Test Epic & Task created:
   Epic ID: 123
   Task ID: 42
   Branch: test-cursor-agent-1730229600

Next steps:
  1. Monitor the agent execution in Cursor dashboard
  2. Set up ngrok for webhook testing: ngrok http 3000
  3. Re-run with TEST_WEBHOOK_URL to test full webhook flow
  4. Proceed to Task 3.3: LLM Service Console Validation

To test again from Rails console:
  load 'script/test_cursor_service.rb'

To test launch_agent manually from console:
  cursor = Services::CursorAgentService.new(cursor_credential)
  cursor.launch_agent(
    task: task,
    webhook_url: 'https://your-url.ngrok.io/webhooks/cursor/#{task.id}',
    branch_name: 'test-branch-name'
  )

================================================================================
```

### Expected Output (Without Webhook URL):

```
================================================================================
Cursor Service Console Validation
Task 3.2: Testing Cursor Agent Launch with API Credentials
================================================================================

Step 1: Validating environment setup
--------------------------------------------------------------------------------
✓ CURSOR_KEY found
✓ GITHUB_TOKEN found
⚠️  TEST_WEBHOOK_URL not set. Using placeholder URL.
   Note: Agent will launch but webhook callbacks won't work with placeholder.

[... rest of setup steps ...]

Launch parameters:
  Task ID: 42
  Task Description: Add comment to README explaining the purpose of this repository
  Repository: https://github.com/landovsky/orchestra-ai
  Base Branch: main
  Target Branch: test-cursor-agent-1730229600
  Webhook URL: https://placeholder.example.com/webhooks/cursor/42

⚠️  WARNING: Using placeholder webhook URL
   Agent will launch but callbacks won't reach your application.
   Set TEST_WEBHOOK_URL to test full webhook flow.

Launching Cursor agent...
--------------------------------------------------------------------------------
✓ SUCCESS: Agent launched successfully!

[... continues normally ...]
```

## Manual Console Session

### Complete Walkthrough

```ruby
# Step 1: Ensure prerequisites
irb(main):001:0> user = User.first
=> #<User id: 1, email: "test@example.com", ...>

# Step 2: Create GitHub credential (for repository)
irb(main):002:0> github_cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'github_token',
  api_key: ENV['GITHUB_TOKEN']
)
=> #<Credential id: 1, service_name: "github", ...>

# Step 3: Create Cursor credential
irb(main):003:0> cursor_cred = Credential.create!(
  user: user,
  service_name: 'cursor_agent',
  name: 'cursor_api',
  api_key: ENV['CURSOR_KEY']
)
=> #<Credential id: 2, service_name: "cursor_agent", ...>

# Step 4: Create repository
irb(main):004:0> repo = Repository.create!(
  user: user,
  name: 'orchestra-ai',
  github_url: 'https://github.com/landovsky/orchestra-ai',
  github_credential: github_cred
)
=> #<Repository id: 1, name: "orchestra-ai", ...>

# Step 5: Create epic
irb(main):005:0> epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'Test Epic',
  base_branch: 'main',
  status: 'pending',
  cursor_agent_credential: cursor_cred
)
=> #<Epic id: 1, title: "Test Epic", base_branch: "main", ...>

# Step 6: Create task
irb(main):006:0> task = Task.create!(
  epic: epic,
  description: 'Add comment to README',
  position: 1,
  status: 'pending'
)
=> #<Task id: 1, description: "Add comment to README", ...>

# Step 7: Initialize Cursor service
irb(main):007:0> cursor = Services::CursorAgentService.new(cursor_cred)
=> #<Services::CursorAgentService:0x00007f... @api_key="sk_xxx...">

# Step 8: Launch agent
irb(main):008:0> result = cursor.launch_agent(
  task: task,
  webhook_url: "https://abc123.ngrok.io/webhooks/cursor/#{task.id}",
  branch_name: "test-manual-#{Time.now.to_i}"
)
=> {"id"=>"bc_abc123xyz...", "status"=>"RUNNING", "createdAt"=>"2025-10-29T20:00:00.123Z", ...}

# Step 9: Check agent ID
irb(main):009:0> result['id']
=> "bc_abc123xyz789def456ghi012jkl345"

# Step 10: Verify task data
irb(main):010:0> task.description
=> "Add comment to README"

irb(main):011:0> task.epic.base_branch
=> "main"

irb(main):012:0> task.epic.repository.github_url
=> "https://github.com/landovsky/orchestra-ai"
```

### Quick Launch (Assuming Setup Exists)

```ruby
# If you've already run the script or set up manually:
irb(main):001:0> user = User.first
=> #<User id: 1, ...>

irb(main):002:0> cursor_cred = user.credentials.find_by(service_name: 'cursor_agent')
=> #<Credential id: 2, service_name: "cursor_agent", ...>

irb(main):003:0> cursor = Services::CursorAgentService.new(cursor_cred)
=> #<Services::CursorAgentService:0x00007f...>

irb(main):004:0> epic = user.epics.last
=> #<Epic id: 1, ...>

irb(main):005:0> task = epic.tasks.first
=> #<Task id: 1, ...>

irb(main):006:0> result = cursor.launch_agent(
  task: task,
  webhook_url: "https://abc123.ngrok.io/webhooks/cursor/#{task.id}",
  branch_name: "quick-test-#{Time.now.to_i}"
)
=> {"id"=>"bc_def456...", "status"=>"RUNNING", ...}
```

## Common Error Scenarios

### 1. Missing Environment Variable

```bash
$ rails runner script/test_cursor_service.rb

================================================================================
Cursor Service Console Validation
Task 3.2: Testing Cursor Agent Launch with API Credentials
================================================================================

Step 1: Validating environment setup
--------------------------------------------------------------------------------
❌ ERROR: Missing required environment variables:
  - CURSOR_KEY environment variable not set

Please set the required environment variables:
  export CURSOR_KEY=your_cursor_api_key
  export GITHUB_TOKEN=your_github_token
  export TEST_WEBHOOK_URL=https://your-ngrok-url.ngrok.io  # Optional
```

**Solution:**
```bash
export CURSOR_KEY=sk_your_actual_key_here
export GITHUB_TOKEN=ghp_your_actual_token_here
```

### 2. Invalid API Key

```
Launching Cursor agent...
--------------------------------------------------------------------------------
❌ API REQUEST FAILED
  Message: Cursor API request failed (401): Unauthorized - Invalid API key

Possible causes:
  - Invalid CURSOR_KEY
  - API endpoint unreachable
  - Rate limiting
  - Invalid request payload
```

**Solution:**
- Verify your Cursor API key is correct
- Check if key has proper permissions
- Ensure key hasn't expired

### 3. Network Connection Error

```
❌ API REQUEST FAILED
  Message: Failed to communicate with Cursor API: Connection refused

Possible causes:
  - API endpoint unreachable
  - Network connectivity issues
  - Firewall blocking requests
```

**Solution:**
- Check internet connectivity
- Verify API endpoint URL
- Check firewall/proxy settings

### 4. Invalid Task Setup

```ruby
irb(main):001:0> cursor.launch_agent(
  task: task_without_epic,
  webhook_url: "https://example.com/webhook",
  branch_name: "test"
)

ArgumentError: Task must belong to an epic
```

**Solution:**
- Ensure task has associated epic
- Ensure epic has repository
- Ensure repository has github_url
- Ensure epic has base_branch

## Verification Checklist

After running the script, verify:

- [ ] ✓ Script completes without errors
- [ ] ✓ Agent ID returned (starts with "bc_")
- [ ] ✓ API response shows "status": "RUNNING"
- [ ] ✓ All validation tests pass
- [ ] ✓ Test epic and task created in database
- [ ] ✓ Can view agent in Cursor dashboard
- [ ] ✓ Webhook URL properly configured (if set)

Optional (for webhook testing):
- [ ] ✓ Ngrok tunnel running
- [ ] ✓ TEST_WEBHOOK_URL set correctly
- [ ] ✓ Can see webhook callbacks in logs

## Next Steps

After successful validation:

1. **Monitor Agent Execution**
   - Log into Cursor dashboard
   - Find agent by ID
   - Watch status changes

2. **Test Webhook Flow (Optional)**
   - Start ngrok: `ngrok http 3000`
   - Copy ngrok URL
   - Re-run script with TEST_WEBHOOK_URL
   - Monitor Rails logs: `tail -f log/development.log`

3. **Proceed to Next Task**
   - Task 3.3: LLM Service Console Validation
   - Then Phase 4: Manual Epic Creation

## Troubleshooting

### Agent Launches but No Activity

**Symptoms:** Agent ID returned, but no visible activity
**Possible Causes:**
- Repository access issues
- Branch already exists
- Insufficient permissions

**Solution:**
- Verify repository URL is accessible
- Check branch doesn't already exist
- Ensure Cursor has repository access

### Webhook Not Receiving Callbacks

**Symptoms:** Agent completes but no webhook received
**Possible Causes:**
- Invalid webhook URL
- Ngrok tunnel closed
- Wrong webhook secret

**Solution:**
- Verify ngrok is running
- Check TEST_WEBHOOK_URL is correct
- Ensure CURSOR_WEBHOOK_SECRET matches
- Monitor `tail -f log/development.log`

### Script Hangs During Launch

**Symptoms:** Script stops at "Launching Cursor agent..."
**Possible Causes:**
- Timeout waiting for API
- Network slowness
- API rate limiting

**Solution:**
- Wait up to 30 seconds (read timeout)
- Check network connection
- Verify API rate limits not exceeded
- Try again after a few minutes

---

**Reference:** Phase 3, Task 3.2 - Cursor Service Console Validation  
**Related Files:**
- `script/test_cursor_service.rb`
- `lib/services/cursor_agent_service.rb`
- `docs/TASK-3.2-COMPLETED.md`
