# Specification: Fix GithubService Test Suite

## Objective

Fix the failing RSpec test suite for `Services::GithubService` by preventing real HTTP calls to GitHub's API during test execution. All tests currently fail with "401 - Bad credentials" because they attempt to authenticate with GitHub using test fixtures.

## Motivation

The current test suite is:
- **Unreliable**: Tests fail due to external API calls with invalid credentials
- **Slow**: Would make real HTTP requests if credentials were valid
- **Brittle**: Depends on external service availability and network connectivity
- **Insecure**: Would expose real GitHub tokens in test environment

A properly isolated test suite will:
- Run in milliseconds without network calls
- Pass consistently in any environment (CI, local, offline)
- Allow comprehensive testing of edge cases and error conditions
- Require no secrets or external service access

## Current State

**Files involved:**
- `spec/services/github_service_spec.rb` - Comprehensive test suite (267 lines)
- `app/services/github_service.rb` - Service class wrapping Octokit client

**Problem:**
Tests create a real `Octokit::Client` instance during service initialization, which attempts authentication with GitHub API. The mock client is stubbed too late in the test lifecycle.

**Test coverage includes:**
- Initialization and configuration
- Pull request merging (happy path, not found, not mergeable, conflicts)
- Branch deletion (success, not found, errors)
- Base branch inference (various branch names, repository not found, auth errors)
- Comprehensive validation of task/epic/repository associations

## Requirements

### Must Have

1. **Prevent real HTTP calls**: No test should make actual requests to GitHub's API
2. **All existing tests must pass**: Current test assertions and expectations remain valid
3. **Fast execution**: Test suite should complete in under 1 second
4. **No external dependencies**: Tests should run offline without configuration
5. **Maintain test coverage**: All current test cases and edge cases must remain

### Test Suite Structure

The test suite should continue to validate:

**Initialization tests:**
- Successful initialization with valid credentials
- Proper client configuration (auto_paginate, access_token)
- Argument validation (nil credentials, missing api_key)

**merge_pull_request tests:**
- Successful merge with mergeable PR
- PR not found scenarios
- PR not mergeable scenarios
- Octokit error handling (NotFound, MethodNotAllowed, Conflict)
- Task validation (nil task, missing branch_name, missing associations)

**delete_branch tests:**
- Successful branch deletion
- Branch not found scenarios
- Deletion failures
- Task validation
- Special characters in branch names

**infer_base_branch tests:**
- Default branch retrieval (main, master, custom)
- Repository not found scenarios
- Authentication and authorization errors
- Repository name validation

### Success Criteria

1. ✅ `bundle exec rspec spec/services/github_service_spec.rb` passes completely
2. ✅ No real HTTP requests are made (can verify with network monitoring)
3. ✅ Test suite runs in under 1 second
4. ✅ Tests pass without internet connection
5. ✅ No environment variables or secrets required
6. ✅ All current test assertions remain unchanged

## Constraints

- **Do not modify** the service implementation (`app/services/github_service.rb`)
- **Do not remove** any existing test cases
- **Do not change** test assertions or expected behaviors
- **Minimize changes** to test descriptions and structure
- **Use only** RSpec and standard Ruby testing tools (no additional gems unless absolutely necessary)

## Out of Scope

- Integration tests with real GitHub API (future consideration)
- VCR cassette recordings (not needed for unit tests)
- Testing other service classes
- Modifying the GithubService implementation
- Adding new test cases (focus is on making existing tests pass)

## Deliverables

1. **Updated test file** (`spec/services/github_service_spec.rb`) with all tests passing
2. **Brief summary** of changes made and approach taken

## Notes

- The Octokit::Client is instantiated during `GithubService.new(credential)` initialization
- Tests need to intercept client creation before service initialization occurs
- Mock client must support all methods called during tests: `auto_paginate=`, `auto_paginate`, `access_token`, `pull_requests`, `merge_pull_request`, `delete_ref`, `repository`
- Current test structure uses `let` blocks and `before` hooks - maintain this pattern for consistency