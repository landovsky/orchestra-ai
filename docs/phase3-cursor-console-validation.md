# Phase 3 - Task 3.2: Cursor Service Console Validation

**Status:** ✅ COMPLETED  
**Date:** 2025-10-29

## Overview

This guide provides instructions for validating the Cursor service integration using Rails console and automated scripts. This validation ensures the application can successfully launch Cursor AI agents with real API credentials.

## Prerequisites

### Required Environment Variables

```bash
# Cursor API key (required)
export CURSOR_KEY=sk_your_cursor_api_key_here

# GitHub token (required for repository credential)
export GITHUB_TOKEN=ghp_your_github_token_here

# Webhook URL (optional but recommended for full testing)
export TEST_WEBHOOK_URL=https://your-ngrok-url.ngrok.io
```

### Optional: Setup Ngrok for Webhook Testing

```bash
# In a separate terminal
ngrok http 3000

# Copy the HTTPS URL and set it as TEST_WEBHOOK_URL
export TEST_WEBHOOK_URL=https://abc123.ngrok.io
```

### Database Requirements

- At least one User record (script will create if missing)
- Rails application running and configured

## Validation Methods

### Method 1: Automated Script (Recommended)

The automated script handles all setup and testing automatically.

```bash
# Run the validation script
rails runner script/test_cursor_service.rb
```

**What the script does:**
1. ✅ Validates environment variables
2. ✅ Sets up test user (if needed)
3. ✅ Creates/updates credentials
4. ✅ Creates test repository
5. ✅ Creates test epic and task
6. ✅ Initializes Cursor service
7. ✅ Launches agent with real API call
8. ✅ Validates error handling
9. ✅ Displays results and next steps

**Expected outcome:**
- Agent ID returned (e.g., "bc_abc123...")
- All validation tests pass
- Clear success/failure indicators

### Method 2: Manual Console Testing

Step-by-step manual testing from Rails console.

```bash
# Start Rails console
rails console
```

#### Step 1: Setup User and Credentials

```ruby
# Get or create user
user = User.first || User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Create GitHub credential (for repository)
github_cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'github_token',
  api_key: ENV['GITHUB_TOKEN']
)

# Create Cursor credential
cursor_cred = Credential.create!(
  user: user,
  service_name: 'cursor_agent',
  name: 'cursor_api',
  api_key: ENV['CURSOR_KEY']
)
```

#### Step 2: Setup Repository

```ruby
# Create repository
repo = Repository.create!(
  user: user,
  name: 'test-repo',
  github_url: 'https://github.com/landovsky/orchestra-ai',
  github_credential: github_cred
)
```

#### Step 3: Create Epic and Task

```ruby
# Create epic
epic = Epic.create!(
  user: user,
  repository: repo,
  title: 'Test Epic - Manual',
  base_branch: 'main',
  status: 'pending',
  cursor_agent_credential: cursor_cred
)

# Create task
task = Task.create!(
  epic: epic,
  description: 'Add comment to README explaining the purpose of this repository',
  position: 1,
  status: 'pending'
)
```

#### Step 4: Initialize Service and Launch Agent

```ruby
# Initialize Cursor service
cursor = Services::CursorAgentService.new(cursor_cred)

# Launch agent
result = cursor.launch_agent(
  task: task,
  webhook_url: "https://your-ngrok-url.ngrok.io/webhooks/cursor/#{task.id}",
  branch_name: "test-manual-#{Time.now.to_i}"
)

# Check result
result['id']  # Should return agent ID like "bc_abc123..."
```

## Testing Scenarios

### 1. Full Test with Webhook

**Setup:**
```bash
# Terminal 1: Start ngrok
ngrok http 3000

# Terminal 2: Set environment and run script
export CURSOR_KEY=sk_xxx
export GITHUB_TOKEN=ghp_xxx
export TEST_WEBHOOK_URL=https://abc123.ngrok.io
rails runner script/test_cursor_service.rb
```

**Expected Results:**
- ✅ Agent launches successfully
- ✅ Agent ID returned
- ✅ Webhook URL configured
- ✅ Can monitor webhooks in Rails logs

### 2. Minimal Test (No Webhook)

**Setup:**
```bash
export CURSOR_KEY=sk_xxx
export GITHUB_TOKEN=ghp_xxx
rails runner script/test_cursor_service.rb
```

**Expected Results:**
- ✅ Agent launches successfully
- ⚠️ Warning about placeholder webhook
- ✅ Agent ID returned
- ℹ️ Webhook callbacks won't work

### 3. Error Handling Test

The script automatically tests various error conditions:

```ruby
# Test 1: Nil task
cursor.launch_agent(task: nil, webhook_url: "url", branch_name: "branch")
# => ArgumentError: Task cannot be nil

# Test 2: Blank webhook URL
cursor.launch_agent(task: task, webhook_url: "", branch_name: "branch")
# => ArgumentError: webhook_url cannot be blank

# Test 3: Blank branch name
cursor.launch_agent(task: task, webhook_url: "url", branch_name: "")
# => ArgumentError: branch_name cannot be blank

# Test 4: Task without description
cursor.launch_agent(task: invalid_task, webhook_url: "url", branch_name: "branch")
# => ArgumentError: Task must have a description
```

## API Request Details

### Request Payload Structure

```json
{
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
  },
  "webhook": {
    "url": "https://abc123.ngrok.io/webhooks/cursor/42",
    "secret": "<CURSOR_WEBHOOK_SECRET>"
  }
}
```

### Successful Response

```json
{
  "id": "bc_abc123xyz789def456ghi012jkl345",
  "status": "RUNNING",
  "createdAt": "2025-10-29T20:00:00.123Z",
  "prompt": { ... },
  "source": { ... },
  "target": { ... }
}
```

## Acceptance Criteria

✅ **Can launch Cursor agent and get back agent ID**

Verification steps:
1. Script runs without errors
2. API returns successful response (200 OK)
3. Response contains agent ID field
4. Agent ID is valid (non-empty string)
5. All error handling tests pass
6. Webhook URL is correctly configured

## Monitoring Agent Execution

### 1. Cursor Dashboard

- Log into Cursor dashboard
- Find agent by ID from script output
- Monitor status changes:
  - RUNNING → agent is working
  - FINISHED → agent completed successfully
  - ERROR → agent encountered an issue

### 2. Webhook Callbacks (if configured)

```bash
# Monitor Rails logs
tail -f log/development.log

# Look for webhook POST requests
# Expected callbacks:
# - RUNNING: Agent started
# - FINISHED: Agent completed, includes PR URL
# - ERROR: Agent failed, includes error message
```

### 3. GitHub

- Watch for new branch creation
- Monitor for PR creation
- Check PR description and changes

## Troubleshooting

### Problem: Missing Environment Variable

**Error:**
```
❌ ERROR: Missing required environment variables:
  - CURSOR_KEY environment variable not set
```

**Solution:**
```bash
export CURSOR_KEY=sk_your_actual_key_here
export GITHUB_TOKEN=ghp_your_actual_token_here
```

### Problem: Invalid API Key

**Error:**
```
❌ API REQUEST FAILED
  Message: Cursor API request failed (401): Unauthorized
```

**Solution:**
- Verify CURSOR_KEY is correct
- Check if key has proper permissions
- Ensure key hasn't expired
- Generate new API key if needed

### Problem: Network Connection Error

**Error:**
```
❌ API REQUEST FAILED
  Message: Failed to communicate with Cursor API: Connection refused
```

**Solution:**
- Check internet connectivity
- Verify firewall settings
- Check if API endpoint is accessible
- Try again after a few minutes

### Problem: Task Validation Error

**Error:**
```
ArgumentError: Task must belong to an epic
```

**Solution:**
Ensure complete data setup:
```ruby
# Verify associations
task.epic.present?  # Must be true
task.epic.repository.present?  # Must be true
task.epic.repository.github_url.present?  # Must be true
task.epic.base_branch.present?  # Must be true
task.description.present?  # Must be true
```

### Problem: Webhook Not Working

**Symptoms:** Agent launches but no webhook callbacks received

**Solution:**
1. Verify ngrok is running: `ngrok http 3000`
2. Check TEST_WEBHOOK_URL is set correctly
3. Ensure URL includes protocol (https://)
4. Monitor logs: `tail -f log/development.log`
5. Verify CURSOR_WEBHOOK_SECRET matches

## Files Reference

### Created/Modified Files

```
/workspace/
├── script/
│   └── test_cursor_service.rb          # Main validation script
└── docs/
    ├── TASK-3.2-COMPLETED.md           # Completion documentation
    ├── phase3-cursor-console-validation.md  # This file
    ├── phase3-cursor-validation-example-output.md  # Example output
    └── console-commands-phase3.md      # Updated with Cursor script
```

### Related Files

- `lib/services/cursor_agent_service.rb` - Service implementation
- `spec/services/cursor_agent_service_spec.rb` - Unit tests
- `app/models/task.rb` - Task model
- `app/models/epic.rb` - Epic model
- `app/models/repository.rb` - Repository model
- `app/models/credential.rb` - Credential model

## Next Steps

After successful validation:

1. **Proceed to Task 3.3**
   - LLM Service Console Validation
   - Test spec generation from prompts

2. **Move to Phase 4**
   - Manual Epic Creation
   - Basic Interactions
   - Start building automation

3. **Future Enhancements**
   - Webhook controller implementation (Task 5.2)
   - Webhook handlers (Task 5.3)
   - Full task execution flow (Phase 5)

## Quick Reference

### Run Automated Script
```bash
export CURSOR_KEY=sk_xxx
export GITHUB_TOKEN=ghp_xxx
export TEST_WEBHOOK_URL=https://abc123.ngrok.io  # Optional
rails runner script/test_cursor_service.rb
```

### Quick Console Test
```ruby
user = User.first
cursor_cred = user.credentials.find_by(service_name: 'cursor_agent')
cursor = Services::CursorAgentService.new(cursor_cred)
epic = user.epics.last
task = epic.tasks.first

result = cursor.launch_agent(
  task: task,
  webhook_url: "https://abc123.ngrok.io/webhooks/cursor/#{task.id}",
  branch_name: "test-#{Time.now.to_i}"
)

result['id']  # Agent ID
```

### Monitor Webhooks
```bash
# Start ngrok
ngrok http 3000

# Monitor Rails logs
tail -f log/development.log | grep webhook
```

## Additional Resources

- **Cursor API Documentation:** https://api.cursor.com/docs
- **GitHub OAuth Tokens:** https://github.com/settings/tokens
- **Ngrok Documentation:** https://ngrok.com/docs

---

**Phase:** Phase 3 - Console-First Integration Testing  
**Task:** 3.2 - Cursor Service Console Validation  
**Status:** ✅ COMPLETED  
**Date:** 2025-10-29
