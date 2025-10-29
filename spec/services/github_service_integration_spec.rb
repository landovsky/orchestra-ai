# frozen_string_literal: true

require 'rails_helper'

# =============================================================================
# GitHub Integration Tests - Cassette Recording Required
# =============================================================================
#
# ⚠️ IMPORTANT: These tests WILL FAIL until VCR cassettes are recorded locally.
#
# These tests verify real GitHub API integration using VCR to record/replay
# HTTP interactions. Unlike unit tests that mock everything, these tests
# validate that our Octokit usage matches the actual GitHub API contract.
#
# ## Recording Cassettes (First Time Setup):
#
# 1. Create a GitHub Personal Access Token:
#    - Go to: GitHub → Settings → Developer settings → Personal access tokens
#    - Click "Generate new token (classic)"
#    - Select scope: `public_repo` (for read-only access to public repos)
#    - Generate and copy the token
#
# 2. Record cassettes by running tests with your token:
#    ```bash
#    GITHUB_TOKEN=ghp_your_token_here bundle exec rspec --tag integration
#    ```
#
# 3. Verify cassettes have filtered sensitive data:
#    ```bash
#    grep -r "ghp_" spec/fixtures/vcr_cassettes/  # Should return nothing
#    grep -r "<GITHUB_TOKEN>" spec/fixtures/vcr_cassettes/  # Should find replacements
#    ```
#
# 4. Commit the recorded cassettes:
#    ```bash
#    git add spec/fixtures/vcr_cassettes/
#    git commit -m "Add VCR cassettes for GitHub integration tests"
#    ```
#
# ## Running Tests:
#
# With recorded cassettes (no token needed):
#   bundle exec rspec --tag integration
#
# Skip integration tests (default behavior):
#   bundle exec rspec
#   # or explicitly: bundle exec rspec --tag ~integration
#
# ## Re-recording Cassettes:
#
# If GitHub API changes or tests are updated:
# ```bash
# rm -rf spec/fixtures/vcr_cassettes/Services_GithubService*
# GITHUB_TOKEN=ghp_your_token_here bundle exec rspec --tag integration
# ```
#
# ## Test Scope:
#
# These tests cover READ-ONLY operations against PUBLIC repositories:
# - ✅ infer_base_branch - Fetch repository default branch
#
# Excluded from scope (require write access):
# - ❌ merge_pull_request - Requires write permissions
# - ❌ delete_branch - Requires write permissions
#
# =============================================================================

RSpec.describe Services::GithubService, :integration, :vcr do
  let(:user) { create(:user) }
  let(:credential) { create(:credential, user: user, service_name: 'github', api_key: ENV['GITHUB_TOKEN'] || 'test-token') }
  let(:service) { described_class.new(credential) }

  describe '#infer_base_branch' do
    context 'with rails/rails public repository' do
      let(:repo_name) { 'rails/rails' }

      it 'returns the default branch name' do
        result = service.infer_base_branch(repo_name)
        
        expect(result).to be_a(String)
        expect(result).not_to be_empty
        # Rails uses 'main' as their default branch
        expect(result).to eq('main')
      end

      it 'fetches repository information from GitHub API' do
        result = service.infer_base_branch(repo_name)
        
        # Verify we got a valid branch name (common default branches)
        expect(['main', 'master', 'develop']).to include(result)
      end
    end

    context 'with octokit/octokit.rb public repository' do
      let(:repo_name) { 'octokit/octokit.rb' }

      it 'returns the default branch name' do
        result = service.infer_base_branch(repo_name)
        
        expect(result).to be_a(String)
        expect(result).not_to be_empty
        # Octokit uses 'main' as their default branch
        expect(result).to eq('main')
      end
    end

    context 'with non-existent repository' do
      let(:repo_name) { 'this-org-does-not-exist-12345/this-repo-does-not-exist-67890' }

      it 'raises StandardError with appropriate message' do
        expect {
          service.infer_base_branch(repo_name)
        }.to raise_error(StandardError, /Repository '#{Regexp.escape(repo_name)}' not found/)
      end
    end

    context 'with invalid repository name format' do
      it 'raises ArgumentError when repo_name is blank' do
        expect {
          service.infer_base_branch('')
        }.to raise_error(ArgumentError, 'Repository name cannot be nil or blank')
      end

      it 'raises ArgumentError when repo_name is nil' do
        expect {
          service.infer_base_branch(nil)
        }.to raise_error(ArgumentError, 'Repository name cannot be nil or blank')
      end
    end
  end
end
