# Task 3.1: GitHub Service Console Validation

## Overview
This document provides instructions for testing the GitHub API integration with real credentials from the Rails console, specifically testing the `infer_base_branch` method.

## Prerequisites

1. **GitHub Personal Access Token**
   - Create a token at: https://github.com/settings/tokens
   - Required scopes: `repo` (or `public_repo` for public repositories only)
   - Set as environment variable:
     ```bash
     export GITHUB_TOKEN=your_token_here
     ```

2. **Rails Environment**
   - Database set up and migrated
   - At least one User record (script will create one if needed)

## Method 1: Automated Test Script

Run the complete validation script:

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token_here

# Run the validation script
rails runner script/test_github_service.rb
```

The script will:
- ✓ Verify GitHub token is set
- ✓ Create/find test user and credential
- ✓ Initialize GitHub service
- ✓ Test `infer_base_branch` on multiple repositories
- ✓ Test error handling with invalid inputs
- ✓ Display comprehensive results

## Method 2: Manual Console Testing

Launch Rails console:
```bash
rails console
```

Then execute the following commands:

### Step 1: Create Credential
```ruby
# Get or create a user
user = User.first || User.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Create GitHub credential
cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'github_token',
  api_key: ENV['GITHUB_TOKEN']
)
```

### Step 2: Initialize GitHub Service
```ruby
gh = Services::GithubService.new(cred)
```

### Step 3: Test infer_base_branch Method
```ruby
# Test with a known repository
gh.infer_base_branch('landovsky/orchestra-ai')
# => "main" (or whatever the default branch is)

# Test with other popular repositories
gh.infer_base_branch('rails/rails')
# => "main"

gh.infer_base_branch('torvalds/linux')
# => "master"
```

### Step 4: Test Error Handling
```ruby
# Test with non-existent repository
begin
  gh.infer_base_branch('this-repo/does-not-exist')
rescue StandardError => e
  puts "Expected error: #{e.message}"
end
# => "Repository 'this-repo/does-not-exist' not found"

# Test with invalid input
begin
  gh.infer_base_branch(nil)
rescue ArgumentError => e
  puts "Expected error: #{e.message}"
end
# => "Repository name cannot be nil or blank"
```

## Expected Results

### Success Criteria
- ✓ GitHub service initializes without errors
- ✓ `infer_base_branch` returns correct default branch for valid repositories
- ✓ Method properly handles different default branches (main, master, develop, etc.)
- ✓ Appropriate errors raised for invalid inputs
- ✓ Clear error messages for authentication/permission issues

### Common Issues

1. **"Authentication failed"**
   - Verify your GitHub token is valid
   - Check token hasn't expired
   - Ensure token is properly set in environment

2. **"Access forbidden"**
   - Token may lack required scopes
   - Add `repo` scope to your token
   - For public repos only, `public_repo` scope is sufficient

3. **"Repository not found"**
   - Check repository name format (must be `owner/repo`)
   - Verify you have access to the repository
   - For private repos, ensure your token has appropriate permissions

## Testing Other Methods

The GitHub service also provides these methods (for future testing):

### merge_pull_request(task)
```ruby
# Requires a Task with:
# - branch_name
# - epic with repository
# - open pull request for the branch

# Example (after PR is created):
# gh.merge_pull_request(task)
# => "abc123def456" (merge commit SHA)
```

### delete_branch(task)
```ruby
# Requires a Task with:
# - branch_name
# - epic with repository

# Example (after branch is merged):
# gh.delete_branch(task)
# => true
```

## Next Steps

After validating the GitHub service:
- **Task 3.2**: Cursor Service Console Validation
- **Task 3.3**: LLM Service Console Validation
- **Phase 4**: Manual Epic Creation & Basic Interactions

## Troubleshooting

### Script doesn't run
```bash
# Ensure script is executable
chmod +x script/test_github_service.rb

# Run with explicit rails runner
bundle exec rails runner script/test_github_service.rb
```

### Token issues
```bash
# Verify token is set
echo $GITHUB_TOKEN

# Test token directly with curl
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user
```

### Database issues
```bash
# Ensure database is set up
rails db:create db:migrate

# Check if users exist
rails console
User.count
```

## Reference

See `docs/spec-orchestrator.md` for the full implementation plan and Phase 3 details.
