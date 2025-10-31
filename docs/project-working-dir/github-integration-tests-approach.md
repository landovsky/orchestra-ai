# Specification: Add VCR Integration Smoke Tests for GithubService

## ⚠️ CRITICAL: Implementation Only - Do Not Run Tests

**AI Agent Instructions:**
- ✅ Create test files, VCR configuration, and documentation
- ✅ Create a simple VCR smoke test to verify VCR works (public website, no auth)
- ❌ Do NOT attempt to run GitHub integration tests (require real credentials)
- ❌ Do NOT try to fix failures or validate tests pass
- ❌ Do NOT create mock cassettes for GitHub tests

**Post-Implementation (Human):** Set up GitHub token, record cassettes locally, commit them.

---

## Objective

Create VCR integration test infrastructure for `Services::GithubService` to verify GitHub API integration. Include a simple smoke test to validate VCR configuration works.

## Motivation

- **Verify API Contract**: Ensure Octokit usage matches real GitHub API
- **Detect Breaking Changes**: Catch GitHub/Octokit API changes
- **Complement Unit Tests**: Unit tests mock everything; these verify real integration

## Requirements

### 1. VCR Configuration

**Setup:**
- Install `vcr` (~> 6.0) and `webmock` (~> 3.0) gems
- Configure in `spec/support/vcr.rb` or `spec/rails_helper.rb`
- Cassette directory: `spec/fixtures/vcr_cassettes/`
- Filter sensitive data: `ENV['GITHUB_TOKEN']` → `<GITHUB_TOKEN>`
- Record mode: `:once` (never overwrite)
- Enable RSpec metadata integration (`:vcr` tag)

**RSpec Config:**
- Exclude integration tests by default: `config.filter_run_excluding integration: true`
- Allow explicit run: `rspec --tag integration`

### 2. VCR Smoke Test (Must Run Successfully)

**File:** `spec/vcr_smoke_spec.rb`

**Purpose:** Verify VCR is configured correctly and creates cassettes

**Requirements:**
- Test against simple public API (e.g., `https://api.github.com/zen` - no auth required)
- Tagged with `:vcr` only (NOT `:integration`)
- Should pass immediately and create cassette
- Validates VCR setup before attempting GitHub integration tests

**Example test:**
```ruby
# Verify VCR configuration works
it 'records HTTP interactions' do
  response = Net::HTTP.get(URI('https://api.github.com/zen'))
  expect(response).to be_a(String)
  expect(response.length).to be > 0
end
```

This test proves VCR is working before dealing with authentication.

### 3. GitHub Integration Tests

**File:** `spec/services/github_service_integration_spec.rb`

**Tests to create:**
- `#infer_base_branch` - Fetch default branch from `rails/rails`
- Tagged with `:integration` and `:vcr`
- Include documentation header explaining cassette recording workflow

**Exclude from scope:**
- `merge_pull_request` - Requires write access
- `delete_branch` - Requires write access

### 4. Documentation

**Include in test file header or README:**

```markdown
## GitHub Integration Tests - Cassette Recording Required

⚠️ These tests WILL FAIL until cassettes are recorded locally.

### Recording Cassettes:
1. Create GitHub token: Settings → Developer settings → Personal access tokens → `public_repo` scope
2. Record: `GITHUB_TOKEN=xxx bundle exec rspec --tag integration`
3. Verify cassettes have `<GITHUB_TOKEN>` placeholder
4. Commit cassettes: `git add spec/fixtures/vcr_cassettes/`

### Running:
- With cassettes: `bundle exec rspec --tag integration`
- Skip integration: `bundle exec rspec --tag ~integration` (default)

### Re-recording:
```bash
rm -rf spec/fixtures/vcr_cassettes/Services_GithubService*
GITHUB_TOKEN=xxx bundle exec rspec --tag integration
```
```

## Deliverables

1. **Gemfile**: Add `vcr` and `webmock` gems (test group)
2. **VCR Config**: `spec/support/vcr.rb` with filtering and RSpec integration
3. **Smoke Test**: `spec/vcr_smoke_spec.rb` - Must pass immediately
4. **Integration Tests**: `spec/services/github_service_integration_spec.rb` - Will fail initially
5. **Documentation**: Clear cassette recording instructions
6. **RSpec Config**: Exclude `:integration` tag by default

## Success Criteria

**Immediate (AI Agent):**
- ✅ VCR smoke test passes and creates cassette in `spec/fixtures/vcr_cassettes/`
- ✅ Integration test file created with proper structure
- ✅ Configuration complete and documented
- ✅ GitHub integration tests fail with clear VCR error (expected)

**After Human Records Cassettes:**
- Tests pass using recorded cassettes
- No sensitive data in cassettes
- Tests run without GitHub token

## Constraints

- Use `rails/rails` public repository for tests
- Read-only operations only
- Exclude integration tests from default runs
- Do not create fake cassettes for GitHub tests
- VCR smoke test must use public endpoint (no auth)

## Out of Scope

- Running/validating GitHub integration tests during implementation
- Write operations (merge, delete)
- Private repositories
- Creating test repositories

---

**Key Insight:** The VCR smoke test validates the infrastructure works, while GitHub integration tests validate the actual service (once cassettes are recorded).