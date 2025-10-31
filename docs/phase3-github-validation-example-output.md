# Example Output: GitHub Service Console Validation

This document shows expected output when running the GitHub service validation script.

## Automated Script Output

```bash
$ export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ rails runner script/test_github_service.rb
```

### Expected Output:

```
================================================================================
GitHub Service Console Validation
Task 3.1: Testing GitHub API Integration
================================================================================

✓ GitHub token found in environment

✓ Using existing user: test@example.com

Creating new GitHub credential...
✓ Created new credential

Initializing GitHub service...
✓ GitHub service initialized successfully
  - Auto-pagination enabled: true

================================================================================
Testing infer_base_branch method
================================================================================

Testing repository: landovsky/orchestra-ai
--------------------------------------------------------------------------------
✓ SUCCESS
  Repository: landovsky/orchestra-ai
  Default branch: main

Testing repository: rails/rails
--------------------------------------------------------------------------------
✓ SUCCESS
  Repository: rails/rails
  Default branch: main

Testing repository: torvalds/linux
--------------------------------------------------------------------------------
✓ SUCCESS
  Repository: torvalds/linux
  Default branch: master

================================================================================
Testing error handling
================================================================================

Test 1: Invalid repository name
✓ Correctly raised error: Repository 'this-repo/does-not-exist-12345' not found: GET https://api.github.com/repos/this-repo/does-not-exist-12345: 404 - Not Found

Test 2: Nil repository name
✓ Correctly raised ArgumentError: Repository name cannot be nil or blank

Test 3: Empty repository name
✓ Correctly raised ArgumentError: Repository name cannot be nil or blank

================================================================================
Validation Complete
================================================================================

✓ GitHub API integration is working correctly
✓ infer_base_branch method tested successfully

Next steps (for reference):
  - Task 3.2: Test merge_pull_request with real PR
  - Task 3.3: Test delete_branch after merge

To test other methods from console:
  gh = Services::GithubService.new(credential)
  gh.infer_base_branch('owner/repo')
  # gh.merge_pull_request(task)  # Requires task with PR
  # gh.delete_branch(task)        # Requires task with branch

================================================================================
```

## Manual Console Session

```ruby
irb(main):001:0> user = User.first
=> #<User id: 1, email: "test@example.com", ...>

irb(main):002:0> cred = Credential.create!(
  user: user,
  service_name: 'github',
  name: 'github_token',
  api_key: ENV['GITHUB_TOKEN']
)
=> #<Credential id: 1, user_id: 1, service_name: "github", name: "github_token", ...>

irb(main):003:0> gh = Services::GithubService.new(cred)
=> #<Services::GithubService:0x00007f8b8c123456 @credential=#<Credential id: 1...>, @client=#<Octokit::Client...>>

irb(main):004:0> gh.infer_base_branch('landovsky/orchestra-ai')
=> "main"

irb(main):005:0> gh.infer_base_branch('rails/rails')
=> "main"

irb(main):006:0> gh.infer_base_branch('torvalds/linux')
=> "master"

irb(main):007:0> # Test error handling
irb(main):008:0> gh.infer_base_branch(nil)
ArgumentError: Repository name cannot be nil or blank

irb(main):009:0> gh.infer_base_branch('invalid/repo-name-12345')
StandardError: Repository 'invalid/repo-name-12345' not found: GET https://api.github.com/repos/invalid/repo-name-12345: 404 - Not Found
```

## Verification Checklist

After running validation, verify:

- [x] GitHub service initializes without errors
- [x] `infer_base_branch` works with valid repositories
- [x] Method returns correct default branch names
- [x] Handles different branch names (main, master, develop)
- [x] Raises ArgumentError for nil/blank input
- [x] Raises StandardError with clear message for non-existent repos
- [x] Raises StandardError for authentication issues
- [x] Client has auto-pagination enabled

## Troubleshooting Common Errors

### Error: "Authentication failed"

```
✓ GitHub token found in environment
✓ Using existing user: test@example.com
✓ Created new credential

Initializing GitHub service...
✓ GitHub service initialized successfully

Testing repository: landovsky/orchestra-ai
❌ FAILED
  Repository: landovsky/orchestra-ai
  Error: Authentication failed: GET https://api.github.com/repos/...: 401 - Unauthorized
```

**Solution:**
- Verify your GitHub token is correct
- Check token hasn't expired
- Regenerate token if needed

### Error: "Access forbidden"

```
❌ FAILED
  Repository: landovsky/orchestra-ai
  Error: Access forbidden to repository 'landovsky/orchestra-ai': GET https://api.github.com/repos/...: 403 - Forbidden
```

**Solution:**
- Token may lack required scopes
- Add `repo` scope (or `public_repo` for public repos only)
- For private repos, ensure you have access

### Error: "GITHUB_TOKEN environment variable not set"

```
❌ ERROR: GITHUB_TOKEN environment variable not set

Please set your GitHub Personal Access Token:
  export GITHUB_TOKEN=your_token_here
```

**Solution:**
```bash
export GITHUB_TOKEN=ghp_your_token_here
rails runner script/test_github_service.rb
```

## Next Steps

Once GitHub service validation is complete:

1. **Task 3.2**: Cursor Agent Service validation
2. **Task 3.3**: LLM Service validation
3. **Phase 4**: Manual Epic Creation & Basic Interactions

Each service follows a similar validation pattern with console scripts and manual testing options.
