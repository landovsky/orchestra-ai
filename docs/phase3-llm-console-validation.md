# Phase 3 - Task 3.3: LLM Service Console Validation

**Status:** ✅ COMPLETED  
**Date:** 2025-10-29

## Overview

This guide provides instructions for validating the LLM service integration using Rails console and automated scripts. This validation ensures the application can successfully generate task specifications from high-level prompts using various LLM providers (OpenAI, Anthropic/Claude, Gemini).

## Prerequisites

### Required Environment Variables

You need at least ONE of the following API keys:

```bash
# OpenAI (GPT-4) - Recommended
export OPENAI_KEY=sk-your_openai_api_key_here

# Anthropic/Claude (Claude 3.5 Sonnet) - Recommended
export ANTHROPIC_KEY=sk-ant-your_anthropic_key_here
# OR
export CLAUDE_KEY=sk-ant-your_anthropic_key_here

# Gemini (stub implementation for now)
export GEMINI_KEY=your_gemini_key_here
```

### Database Requirements

- At least one User record (script will create if missing)
- Rails application running and configured

### Getting API Keys

**OpenAI:**
1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Copy and save it securely

**Anthropic/Claude:**
1. Go to https://console.anthropic.com/settings/keys
2. Create a new API key
3. Copy and save it securely

## Validation Methods

### Method 1: Automated Script (Recommended)

The automated script handles all setup and testing automatically.

```bash
# Set your API key(s)
export OPENAI_KEY=sk-xxx     # OR
export ANTHROPIC_KEY=sk-ant-xxx

# Run the validation script
rails runner script/test_llm_service.rb
```

**What the script does:**
1. ✅ Validates environment variables
2. ✅ Sets up test user (if needed)
3. ✅ Creates/updates credentials for each provider
4. ✅ Tests multiple prompts with each provider:
   - User authentication system
   - REST API for blog posts
   - Dark mode toggle feature
5. ✅ Validates error handling
6. ✅ Tests different prompt types (multi-line, special characters, etc.)
7. ✅ Displays comprehensive results and statistics

**Expected outcome:**
- Task lists generated for each prompt
- All validation tests pass
- Clear success/failure indicators for each provider
- Sample output showing generated tasks

### Method 2: Manual Console Testing

Step-by-step manual testing from Rails console.

```bash
# Start Rails console
rails console
```

#### Step 1: Setup User and Credential

```ruby
# Get or create user
user = User.first || User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Create OpenAI credential
openai_cred = Credential.create!(
  user: user,
  service_name: 'openai',
  name: 'openai_api',
  api_key: ENV['OPENAI_KEY']
)

# OR create Anthropic/Claude credential
claude_cred = Credential.create!(
  user: user,
  service_name: 'anthropic',  # or 'claude'
  name: 'claude_api',
  api_key: ENV['ANTHROPIC_KEY']
)
```

#### Step 2: Initialize Service and Generate Spec

```ruby
# Initialize LLM service
llm = Services::LlmService.new(openai_cred)

# Generate spec from prompt
spec = llm.generate_spec(
  "Add user authentication with email/password",
  "main"
)

# View generated tasks
pp spec['tasks']
# => ["Create User model with email and password fields",
#     "Add authentication logic and session management",
#     "Add tests and documentation",
#     "Review and refactor code on branch: main"]
```

## Testing Scenarios

### 1. Single Provider Test

**OpenAI:**
```bash
export OPENAI_KEY=sk-xxx
rails runner script/test_llm_service.rb
```

**Anthropic/Claude:**
```bash
export ANTHROPIC_KEY=sk-ant-xxx
rails runner script/test_llm_service.rb
```

**Expected Results:**
- ✅ Service initializes successfully
- ✅ All test prompts generate valid task lists
- ✅ Each task list has 3-8 tasks
- ✅ Tasks are specific and actionable

### 2. Multi-Provider Test

Test with multiple providers simultaneously:

```bash
export OPENAI_KEY=sk-xxx
export ANTHROPIC_KEY=sk-ant-xxx
rails runner script/test_llm_service.rb
```

**Expected Results:**
- ✅ Both providers tested independently
- ✅ Results compared side-by-side
- ✅ Summary shows success rate per provider

### 3. Error Handling Test

The script automatically tests various error conditions:

```ruby
# Test 1: Nil prompt
llm.generate_spec(nil, 'main')
# => ArgumentError: prompt cannot be blank

# Test 2: Blank prompt
llm.generate_spec('', 'main')
# => ArgumentError: prompt cannot be blank

# Test 3: Nil base_branch
llm.generate_spec('Add feature', nil)
# => ArgumentError: base_branch cannot be blank

# Test 4: Invalid credential
Services::LlmService.new(nil)
# => ArgumentError: Credential cannot be nil

# Test 5: Unsupported service
invalid_cred = Credential.new(service_name: 'unsupported_llm', api_key: 'test')
Services::LlmService.new(invalid_cred)
# => ArgumentError: Unsupported LLM service: unsupported_llm
```

### 4. Complex Prompt Test

Testing with various prompt formats:

```ruby
# Multi-line prompt
multi_line = <<~PROMPT
  Build a user management system with:
  - User registration with email verification
  - Password reset functionality
  - Role-based access control (admin, user, guest)
  - User profile management
PROMPT

spec = llm.generate_spec(multi_line, 'main')

# Special characters
spec = llm.generate_spec(
  "Add OAuth2.0 authentication with JWT tokens & secure session management (v3.0+)",
  "feature/auth-v3"
)

# Short prompt
spec = llm.generate_spec("Add comments", "main")
```

## API Response Structure

### Request

The service sends prompts to the LLM API with a system prompt that instructs the model to return structured JSON.

**System Prompt Template:**
```
You are an AI assistant that helps break down high-level software 
development tasks into specific, actionable subtasks.

Context:
- Base branch: main
- Each task should be specific and implementable independently
- Tasks should be ordered logically (dependencies first)
- Each task description should be clear and actionable

Return ONLY valid JSON in this exact format:
{
  "tasks": [
    "Task 1 description",
    "Task 2 description",
    "Task 3 description"
  ]
}
```

### Expected Response

```json
{
  "tasks": [
    "Create User model with email, password_digest fields and validations",
    "Add bcrypt gem and implement has_secure_password for password encryption",
    "Create SessionsController for login/logout functionality",
    "Add authentication helper methods to ApplicationController",
    "Create login and signup forms with proper validation feedback",
    "Add tests for User model and authentication flow",
    "Update routes to include authentication endpoints"
  ]
}
```

## Sample Output

### Successful Generation

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
  Credential ID: 123

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
    2. Generate PostsController with RESTful actions (index, show, create, update...
    3. Add routes for posts API endpoints
    4. Implement JSON serialization for Post model
    5. Add request validation and error handling
    6. Create API tests for all CRUD operations

  ✓ Task count meets minimum (>= 4)

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
```

## Acceptance Criteria

✅ **Can generate task list from prompt**

Verification steps:
1. Script runs without errors
2. API returns successful response
3. Response contains 'tasks' array with multiple items
4. Each task is a clear, actionable string
5. Tasks are logically ordered
6. Task count is reasonable (3-8 tasks for most prompts)
7. All error handling tests pass
8. Multiple prompt types work correctly

## Provider Comparison

### OpenAI (GPT-4)

**Pros:**
- Excellent task breakdown quality
- Consistent JSON formatting
- Good at understanding context
- Reliable API availability

**Cons:**
- Requires API key and billing setup
- Rate limits on free tier
- Slower than some alternatives

**Recommended for:** Production use, detailed task breakdowns

### Anthropic/Claude (Claude 3.5 Sonnet)

**Pros:**
- High-quality task generation
- Fast response times
- Good at following instructions
- Strong reasoning capabilities

**Cons:**
- Requires API key and billing setup
- Different API structure than OpenAI

**Recommended for:** Production use, alternative to OpenAI

### Gemini

**Status:** Stub implementation  
**Note:** Not yet fully implemented, uses fallback stub for testing

## Troubleshooting

### Problem: Missing API Key

**Error:**
```
❌ ERROR: No LLM API keys found in environment
```

**Solution:**
```bash
# Add at least one API key
export OPENAI_KEY=sk-your_actual_key_here
# OR
export ANTHROPIC_KEY=sk-ant-your_actual_key_here
```

### Problem: Invalid API Key

**Error:**
```
OpenAI API request failed (401): Unauthorized
```

**Solution:**
- Verify API key is correct
- Check if key has proper permissions
- Ensure key hasn't expired
- Verify billing is set up (if required)
- Generate new API key if needed

### Problem: Rate Limiting

**Error:**
```
OpenAI API request failed (429): Rate limit exceeded
```

**Solution:**
- Wait a few minutes before retrying
- Upgrade API plan for higher limits
- Implement retry logic with backoff
- Use alternative provider

### Problem: Invalid JSON Response

**Error:**
```
Failed to parse OpenAI response: unexpected token
```

**Solution:**
- This typically means the LLM returned malformed JSON
- The service will automatically fall back to stub implementation
- If persistent, check system prompt configuration
- May be a temporary API issue

### Problem: Empty Task List

**Symptom:** Response has empty 'tasks' array

**Solution:**
- Verify prompt is clear and specific
- Check base_branch is valid
- Try different prompt wording
- Ensure API key has proper permissions

### Problem: Network Connection Error

**Error:**
```
Failed to communicate with API: Connection refused
```

**Solution:**
- Check internet connectivity
- Verify firewall settings
- Check if API endpoint is accessible
- Try again after a few minutes
- Verify no proxy issues

## Files Reference

### Created/Modified Files

```
/workspace/
├── script/
│   └── test_llm_service.rb                      # Main validation script
└── docs/
    ├── phase3-llm-console-validation.md         # This file
    └── spec-orchestrator.md                     # Updated with Task 3.3 status
```

### Related Files

- `lib/services/llm_service.rb` - Service implementation
- `spec/services/llm_service_spec.rb` - Unit tests
- `app/models/credential.rb` - Credential model
- `app/models/user.rb` - User model

## Integration with Other Components

### Used By

- `Epics::GenerateSpecJob` (Phase 9) - Background job that calls LLM service
- `EpicsController#create` (Phase 9) - Creates epic from LLM-generated spec
- Console testing and debugging

### Depends On

- `Credential` model - Stores API keys
- `User` model - Owns credentials
- External LLM APIs (OpenAI, Anthropic)

## Next Steps

After successful validation:

1. **Proceed to Phase 4**
   - Task 4.1: Epics::CreateFromManualSpec Interaction
   - Task 4.2: Tasks::UpdateStatus Interaction
   - Task 4.3: Epics::Start Interaction

2. **Later in Phase 9**
   - Task 9.1: Epics::GenerateSpecJob - Use this service in background jobs
   - Task 9.2: "Generate from Prompt" UI - Allow users to generate specs via UI

3. **Production Considerations**
   - Set up proper API key management
   - Implement rate limiting
   - Add caching for similar prompts
   - Monitor API usage and costs
   - Add fallback providers

## Quick Reference

### Run Automated Script

```bash
# With OpenAI
export OPENAI_KEY=sk-xxx
rails runner script/test_llm_service.rb

# With Anthropic
export ANTHROPIC_KEY=sk-ant-xxx
rails runner script/test_llm_service.rb

# With both (compare providers)
export OPENAI_KEY=sk-xxx
export ANTHROPIC_KEY=sk-ant-xxx
rails runner script/test_llm_service.rb
```

### Quick Console Test

```ruby
# Setup
user = User.first
cred = Credential.create!(
  user: user,
  service_name: 'openai',
  api_key: ENV['OPENAI_KEY']
)

# Generate spec
llm = Services::LlmService.new(cred)
spec = llm.generate_spec(
  "Build a user authentication system",
  "main"
)

# View tasks
pp spec['tasks']
```

### Test Custom Prompt

```ruby
# From Rails console
llm = Services::LlmService.new(cred)

spec = llm.generate_spec(
  "Your custom prompt here - be specific about what you want built",
  "main"  # or your base branch
)

# Review generated tasks
spec['tasks'].each_with_index do |task, i|
  puts "#{i + 1}. #{task}"
end
```

## Additional Resources

- **OpenAI API Documentation:** https://platform.openai.com/docs/api-reference
- **OpenAI Pricing:** https://openai.com/pricing
- **Anthropic API Documentation:** https://docs.anthropic.com/claude/reference
- **Anthropic Pricing:** https://www.anthropic.com/pricing
- **Best Practices for Prompting:** https://platform.openai.com/docs/guides/prompt-engineering

## Example Use Cases

### 1. Epic Creation from Prompt

```ruby
# User submits: "Build a blog with posts, comments, and tags"
# LLM generates:

{
  "tasks": [
    "Create Post model with title, content, published_at fields",
    "Create Comment model with content, belongs_to post and user",
    "Create Tag model and PostTag join table for many-to-many relationship",
    "Add has_many associations between Post, Comment, and Tag models",
    "Create PostsController with CRUD actions",
    "Create CommentsController for adding/removing comments",
    "Add views for posts (index, show, form)",
    "Implement tagging functionality in post form",
    "Add tests for models and controllers"
  ]
}

# Each task becomes a Task record in the database
# Tasks are executed sequentially by Cursor agents
```

### 2. Feature Enhancement

```ruby
# User submits: "Add real-time notifications"
# LLM generates:

{
  "tasks": [
    "Set up ActionCable for WebSocket connections",
    "Create Notification model with user_id, message, read_at fields",
    "Create NotificationChannel for broadcasting notifications",
    "Add notifications controller for marking as read",
    "Create notification bell component in header",
    "Add JavaScript to subscribe to notification channel",
    "Create notification views and partials",
    "Add tests for notification functionality"
  ]
}
```

### 3. API Development

```ruby
# User submits: "Create REST API for mobile app"
# LLM generates:

{
  "tasks": [
    "Set up API versioning structure (api/v1)",
    "Add JWT authentication for API endpoints",
    "Create API base controller with error handling",
    "Implement API::V1::UsersController with CRUD",
    "Implement API::V1::PostsController with CRUD",
    "Add API serializers for JSON responses",
    "Add API routes and documentation",
    "Create API integration tests"
  ]
}
```

---

**Phase:** Phase 3 - Console-First Integration Testing  
**Task:** 3.3 - LLM Service Console Validation  
**Status:** ✅ COMPLETED  
**Date:** 2025-10-29
