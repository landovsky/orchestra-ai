# Phase 3: Console-First Integration Testing

Quick reference for testing services from Rails console.

## Task 3.1: GitHub Service Console Validation

### Quick Start Commands

```ruby
# Create credential with GitHub token
cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'github_token',
  api_key: ENV['GITHUB_TOKEN']
)

# Initialize service
gh = Services::GithubService.new(cred)

# Test methods
gh.infer_base_branch('landovsky/orchestra-ai')
# => "main"

# Later tests (requires real tasks with PRs):
# gh.merge_pull_request(task)
# gh.delete_branch(task)
```

### AC: Can successfully call GitHub API from console with real credentials ✓

---

## Task 3.2: Cursor Service Console Validation

```ruby
# Create credential
cred = Credential.create!(
  service_name: 'cursor_agent',
  name: 'cursor_api',
  api_key: ENV['CURSOR_KEY']
)

# Initialize service
cursor = Services::CursorAgentService.new(cred)

# Create minimal test task
task = Task.create!(
  description: "Add comment to README",
  epic: epic,
  status: 'pending'
)

# Launch agent manually
result = cursor.launch_agent(
  task: task,
  webhook_url: "https://your-ngrok-url/webhooks/cursor/#{task.id}",
  branch_name: "test-manual-#{Time.now.to_i}"
)
```

### AC: Can launch Cursor agent and get back agent ID

---

## Task 3.3: LLM Service Console Validation

```ruby
# Create credential
cred = Credential.create!(
  service_name: 'openai',
  name: 'openai_api',
  api_key: ENV['OPENAI_KEY']
)

# Initialize service
llm = Services::LlmService.new(cred)

# Generate spec
spec = llm.generate_spec(
  "Add user authentication with email/password",
  "main"
)
# => { "tasks": ["Create User model", "Add Devise", ...] }
```

### AC: Can generate task list from prompt

---

## Prerequisites

Before running these commands:

```bash
# Set environment variables
export GITHUB_TOKEN=your_github_token
export CURSOR_KEY=your_cursor_api_key
export OPENAI_KEY=your_openai_api_key

# Start Rails console
rails console

# Ensure you have a user
user = User.first || User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)
```

## Automated Testing

For comprehensive testing with multiple test cases:

```bash
# GitHub Service (Task 3.1)
rails runner script/test_github_service.rb

# Cursor Service (Task 3.2)
rails runner script/test_cursor_service.rb

# Coming soon:
# rails runner script/test_llm_service.rb
```
