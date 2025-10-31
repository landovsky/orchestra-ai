# Task 5.1: Testing Tasks::ExecuteJob from Console

This document shows how to manually test the `Tasks::ExecuteJob` from the Rails console.

## Prerequisites

Before running the test, ensure you have:

1. **Cursor API Key**: Set the `CURSOR_KEY` environment variable
   ```bash
   export CURSOR_KEY='your-cursor-api-key'
   ```

2. **App URL** (for webhook callbacks): Set the `APP_URL` environment variable
   ```bash
   export APP_URL='https://your-ngrok-url.ngrok.io'  # For development with ngrok
   # OR
   export APP_URL='https://your-production-domain.com'  # For production
   ```

3. **GitHub Token** (for repository access): Set the `GITHUB_TOKEN` environment variable
   ```bash
   export GITHUB_TOKEN='your-github-token'
   ```

## Console Test Steps

### Option 1: Using the Test Script

Run the automated test script:

```bash
rails runner script/test_execute_job.rb
```

This script will:
- Set up all necessary test data (user, credentials, repository, epic, task)
- Execute the job
- Display the results

### Option 2: Manual Console Commands

Start the Rails console:

```bash
rails console
```

Then run these commands:

```ruby
# Step 1: Set up test data
user = User.first || User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")

# Create Cursor credential
cursor_cred = Credential.find_or_create_by!(
  user: user,
  service_name: 'cursor_agent',
  name: 'Test Cursor Credential'
) do |cred|
  cred.api_key = ENV['CURSOR_KEY']
end

# Create GitHub credential
github_cred = Credential.find_or_create_by!(
  user: user,
  service_name: 'github',
  name: 'Test GitHub Credential'
) do |cred|
  cred.api_key = ENV['GITHUB_TOKEN']
end

# Create repository (replace with your actual repository URL)
repo = Repository.find_or_create_by!(
  user: user,
  name: 'test-repo'
) do |r|
  r.github_url = 'https://github.com/yourusername/yourrepo'
  r.github_credential = github_cred
end

# Create epic
epic = Epic.find_or_create_by!(
  user: user,
  repository: repo,
  title: 'Test Epic for ExecuteJob'
) do |e|
  e.base_branch = 'main'
  e.cursor_agent_credential = cursor_cred
  e.status = 'running'
end

# Create task
task = Task.create!(
  epic: epic,
  description: "Add a comment to the README.md file explaining what this repository does",
  position: 0,
  status: 'pending'
)

# Step 2: Execute the job
Tasks::ExecuteJob.new.perform(task.id)

# Step 3: Verify the results
task.reload
puts "Status:          #{task.status}"
puts "Cursor Agent ID: #{task.cursor_agent_id}"
puts "Branch Name:     #{task.branch_name}"
puts "\nDebug Log:"
puts task.debug_log
```

## Expected Results

After running the job, the task should be updated with:

1. **Status**: Should be `running`
2. **Cursor Agent ID**: Should be populated with an agent ID from Cursor API (e.g., `"bc_abc123"`)
3. **Branch Name**: Should be generated in format `"cursor-agent/task-{id}-{random}"` (e.g., `"cursor-agent/task-1-a3f2bc4d"`)
4. **Debug Log**: Should contain timestamped log entries:
   ```
   [2025-10-29 12:34:56] Starting task execution...
   [2025-10-29 12:34:57] Launching Cursor agent for branch: cursor-agent/task-1-a3f2bc4d
   [2025-10-29 12:34:59] Cursor agent launched successfully. Agent ID: bc_abc123
   ```

## Acceptance Criteria (✓)

- ✓ Job launches agent via CursorAgentService
- ✓ Agent ID is saved to `task.cursor_agent_id`
- ✓ Branch name is saved to `task.branch_name`
- ✓ Task status is updated to `running`
- ✓ All steps are logged in `task.debug_log`
- ✓ Errors are caught and task is marked as `failed` with error message

## Troubleshooting

### Error: "No Cursor agent credential configured for epic"

Make sure the epic has a cursor_agent_credential set:

```ruby
epic.update!(cursor_agent_credential: cursor_cred)
```

### Error: "Cursor API request failed"

- Verify your `CURSOR_KEY` is valid
- Check your network connection
- Review the error message in the debug log

### Error: "No agent ID returned from Cursor API"

This means the Cursor API responded successfully but didn't include an agent ID. Check:
- The response body in the logs
- Whether the API response format has changed

## Next Steps

After verifying the job works:

1. **Task 5.2**: Set up webhook controller to receive Cursor callbacks
2. **Task 5.3**: Implement webhook FINISHED handler to transition task to `pr_open`

## Related Files

- Job: `app/jobs/tasks/execute_job.rb`
- Service: `lib/services/cursor_agent_service.rb`
- Interaction: `app/interactions/tasks/update_status.rb`
- Task Model: `app/models/task.rb`
