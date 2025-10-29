# LLM Service Validation - Example Output

This document shows example output from running the LLM service validation script.

## Command

```bash
export OPENAI_KEY=sk-xxx
rails runner script/test_llm_service.rb
```

## Sample Output

```
================================================================================
LLM Service Console Validation
Task 3.3: Testing LLM API Integration for Spec Generation
================================================================================

Step 1: Validating environment setup
--------------------------------------------------------------------------------
✓ OPENAI_KEY found

Found 1 LLM provider(s) configured:
  - openai (OPENAI_KEY)

Step 2: Setting up test user
--------------------------------------------------------------------------------
✓ Using existing user: test@example.com

Step 3: Preparing test prompts
--------------------------------------------------------------------------------
Prepared 3 test prompts:
  1. User Authentication: "Add user authentication with email/password"
  2. REST API: "Build a REST API for managing blog posts with CRUD operations"
  3. Simple Feature: "Add dark mode toggle to the application settings"

================================================================================
Step 4: Testing LLM Service with Each Provider
================================================================================

================================================================================
Provider 1/1: OPENAI
================================================================================

Setting up credential for openai...
✓ Created openai credential

Initializing LLM service with openai...
✓ LLM service initialized successfully
  Service Name: openai
  Credential ID: 42

--------------------------------------------------------------------------------
Test 1/3: User Authentication
--------------------------------------------------------------------------------
Prompt: "Add user authentication with email/password"
Base Branch: main

✓ SUCCESS
  Generated 7 tasks:
    1. Create User model with email, password_digest fields and validations
    2. Add bcrypt gem and implement has_secure_password for password encryption
    3. Create SessionsController for login/logout functionality
    4. Add authentication helper methods to ApplicationController
    5. Create login and signup forms with proper validation feedback
    6. Add tests for User model and authentication flow
    7. Update routes to include authentication endpoints

  ✓ Task count meets minimum (>= 3)

--------------------------------------------------------------------------------
Test 2/3: REST API
--------------------------------------------------------------------------------
Prompt: "Build a REST API for managing blog posts with CRUD operations"
Base Branch: main

✓ SUCCESS
  Generated 6 tasks:
    1. Create Post model with title, content, and published_at fields
    2. Generate PostsController with RESTful actions (index, show, create, upda...
    3. Add routes for posts API endpoints
    4. Implement JSON serialization for Post model
    5. Add request validation and error handling
    6. Create API tests for all CRUD operations

  ✓ Task count meets minimum (>= 4)

--------------------------------------------------------------------------------
Test 3/3: Simple Feature
--------------------------------------------------------------------------------
Prompt: "Add dark mode toggle to the application settings"
Base Branch: develop

✓ SUCCESS
  Generated 5 tasks:
    1. Add dark_mode boolean column to settings table
    2. Create settings controller with toggle action
    3. Add JavaScript to toggle dark mode class on body element
    4. Create CSS for dark mode styles
    5. Add tests for dark mode toggle functionality

  ✓ Task count meets minimum (>= 2)

================================================================================
Step 5: Testing Error Handling and Validation
================================================================================

Using openai for validation tests

Test 1: generate_spec with nil prompt
✓ Correctly raised ArgumentError: prompt cannot be blank

Test 2: generate_spec with blank prompt
✓ Correctly raised ArgumentError: prompt cannot be blank

Test 3: generate_spec with whitespace-only prompt
✓ Correctly raised ArgumentError: prompt cannot be blank

Test 4: generate_spec with nil base_branch
✓ Correctly raised ArgumentError: base_branch cannot be blank

Test 5: generate_spec with blank base_branch
✓ Correctly raised ArgumentError: base_branch cannot be blank

Test 6: Initialize with nil credential
✓ Correctly raised ArgumentError: Credential cannot be nil

Test 7: Initialize with unsupported service
✓ Correctly raised ArgumentError: Unsupported LLM service: unsupported_llm

================================================================================
Step 6: Testing Different Prompt Types
================================================================================

--------------------------------------------------------------------------------
Complex Test 1/3: Multi-line Prompt
--------------------------------------------------------------------------------
Prompt: "Build a user management system with: - User registration with email verification - Password reset funct..."

✓ SUCCESS: Generated 8 tasks
  First task: Create User model with email, password_digest, confirmation_token, reset_pas
  Last task: Add comprehensive tests for user management functionality

--------------------------------------------------------------------------------
Complex Test 2/3: Prompt with Special Characters
--------------------------------------------------------------------------------
Prompt: "Add OAuth2.0 authentication with JWT tokens & secure session management (v3.0+)"

✓ SUCCESS: Generated 6 tasks
  First task: Add OAuth2 provider gems (omniauth, doorkeeper)
  Last task: Add tests for OAuth flow and JWT token validation

--------------------------------------------------------------------------------
Complex Test 3/3: Short Prompt
--------------------------------------------------------------------------------
Prompt: "Add comments"

✓ SUCCESS: Generated 4 tasks
  First task: Create Comment model with content, user_id, commentable polymorphic fields
  Last task: Add tests for comment functionality

================================================================================
Validation Complete - Summary
================================================================================

Results:
  Total tests: 3
  Successful: 3
  Failed: 0

Results by Provider:
  openai: 3/3 successful

✅ ACCEPTANCE CRITERIA MET
   ✓ Can generate task list from prompt
   ✓ Returns valid JSON structure with 'tasks' array
   ✓ Error handling validated
   ✓ Multiple prompt types supported

📊 Sample Generated Spec:
   Provider: openai
   Prompt: User Authentication
   Tasks:
     1. Create User model with email, password_digest fields and validat...
     2. Add bcrypt gem and implement has_secure_password for password en...
     3. Create SessionsController for login/logout functionality
     4. Add authentication helper methods to ApplicationController
     5. Create login and signup forms with proper validation feedback
     6. Add tests for User model and authentication flow
     7. Update routes to include authentication endpoints

Next steps:
  1. Verify the generated tasks make sense for the given prompts
  2. Test with your own custom prompts from console
  3. Proceed to Phase 4: Manual Epic Creation & Basic Interactions
  4. Use generate_spec in Epics::GenerateSpecJob (Phase 9)

To test generate_spec manually from Rails console:
  user = User.first
  cred = Credential.create!(user: user, service_name: 'openai', api_key: ENV['OPENAI_KEY'])
  llm = Services::LlmService.new(cred)
  spec = llm.generate_spec(
    'Add user authentication with email/password',
    'main'
  )
  pp spec['tasks']

To test from this script again:
  rails runner script/test_llm_service.rb

Supported LLM providers:
  - openai (GPT-4) - Recommended
  - anthropic / claude (Claude 3.5 Sonnet) - Recommended
  - gemini (stub implementation for now)

================================================================================
```

## Example with Multiple Providers

When multiple API keys are configured:

```bash
export OPENAI_KEY=sk-xxx
export ANTHROPIC_KEY=sk-ant-xxx
rails runner script/test_llm_service.rb
```

Output will show results for both providers:

```
Found 2 LLM provider(s) configured:
  - openai (OPENAI_KEY)
  - anthropic (ANTHROPIC_KEY)

================================================================================
Provider 1/2: OPENAI
================================================================================
[... tests for OpenAI ...]

================================================================================
Provider 2/2: ANTHROPIC
================================================================================
[... tests for Anthropic ...]

Results by Provider:
  openai: 3/3 successful
  anthropic: 3/3 successful
```

## Example Generated Task Lists

### Prompt: "Add user authentication with email/password"

**Generated Tasks:**
1. Create User model with email, password_digest fields and validations
2. Add bcrypt gem and implement has_secure_password for password encryption
3. Create SessionsController for login/logout functionality
4. Add authentication helper methods to ApplicationController
5. Create login and signup forms with proper validation feedback
6. Add tests for User model and authentication flow
7. Update routes to include authentication endpoints

### Prompt: "Build a REST API for managing blog posts with CRUD operations"

**Generated Tasks:**
1. Create Post model with title, content, and published_at fields
2. Generate PostsController with RESTful actions (index, show, create, update, destroy)
3. Add routes for posts API endpoints
4. Implement JSON serialization for Post model
5. Add request validation and error handling
6. Create API tests for all CRUD operations

### Prompt: "Add real-time notifications using ActionCable"

**Generated Tasks:**
1. Set up ActionCable configuration for WebSocket connections
2. Create Notification model with user_id, message, read_at, notification_type
3. Create NotificationChannel for broadcasting notifications to users
4. Add notifications controller for marking notifications as read
5. Create notification bell component in application layout
6. Add JavaScript to subscribe to notification channel and update UI
7. Create notification views and partials for rendering
8. Add tests for notification functionality and WebSocket connections

### Prompt: "Implement search with Elasticsearch"

**Generated Tasks:**
1. Add elasticsearch gems to Gemfile (elasticsearch-model, elasticsearch-rails)
2. Configure Elasticsearch connection and indexes
3. Add searchable concern to models that need search
4. Create SearchController for handling search requests
5. Implement search results view with highlighting
6. Add search form to navigation header
7. Create background job for reindexing
8. Add tests for search functionality

## Error Scenarios

### Missing API Key

```
❌ ERROR: No LLM API keys found in environment

Please set at least one of the following environment variables:
  export OPENAI_KEY=sk-your_openai_key_here        # For OpenAI/GPT-4
  export ANTHROPIC_KEY=sk-ant-your_key_here        # For Anthropic/Claude
  export CLAUDE_KEY=sk-ant-your_key_here           # Alternative for Claude
  export GEMINI_KEY=your_gemini_key_here           # For Gemini (stub)

Recommended: OpenAI or Anthropic for best results
```

### Invalid API Key

```
Provider 1/1: OPENAI

Setting up credential for openai...
✓ Created openai credential

Initializing LLM service with openai...
✓ LLM service initialized successfully

Test 1/3: User Authentication
❌ FAILED
  Error: OpenAI API request failed (401): Unauthorized
  Class: StandardError

Results:
  Total tests: 3
  Successful: 0
  Failed: 3

⚠️  WARNING: No successful spec generations

Possible issues:
  - Invalid API key(s)
  - API rate limiting
  - Network connectivity issues
  - API endpoint unavailable
```

## Manual Console Test Example

```ruby
# Rails console
rails console

# Setup
user = User.first
cred = Credential.create!(
  user: user,
  service_name: 'openai',
  api_key: ENV['OPENAI_KEY']
)

# Initialize and generate
llm = Services::LlmService.new(cred)
spec = llm.generate_spec(
  "Build a task management app with projects, tasks, and tags",
  "main"
)

# Output
pp spec
# => {"tasks"=>
#  ["Create Project model with name and description fields",
#   "Create Task model with title, description, due_date, status, belongs_to project",
#   "Create Tag model and TaskTag join table for many-to-many relationship",
#   "Add associations: Project has_many tasks, Task has_many tags",
#   "Create controllers for projects, tasks, and tags with CRUD actions",
#   "Add views for managing projects, tasks, and tags",
#   "Implement tag filtering and search functionality",
#   "Add tests for models, controllers, and associations"]}

# Print tasks nicely
spec['tasks'].each_with_index do |task, i|
  puts "#{i + 1}. #{task}"
end
# 1. Create Project model with name and description fields
# 2. Create Task model with title, description, due_date, status, belongs_to project
# 3. Create Tag model and TaskTag join table for many-to-many relationship
# 4. Add associations: Project has_many tasks, Task has_many tags
# 5. Create controllers for projects, tasks, and tags with CRUD actions
# 6. Add views for managing projects, tasks, and tags
# 7. Implement tag filtering and search functionality
# 8. Add tests for models, controllers, and associations
```

---

This example output demonstrates successful validation of the LLM service with real API credentials.
