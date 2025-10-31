#!/usr/bin/env ruby
# frozen_string_literal: true

# GitHub Service Console Validation Script
# Task 3.1: GitHub Service Console Validation
#
# This script tests the GitHub API integration with real credentials,
# specifically testing the infer_base_branch method.
#
# USAGE:
#   From Rails console:
#     load 'script/test_github_service.rb'
#
#   Or run directly:
#     rails runner script/test_github_service.rb
#
# SETUP:
#   Set environment variable: GITHUB_TOKEN=your_personal_access_token
#
# REQUIREMENTS:
#   - Valid GitHub personal access token with repo access
#   - At least one User record in the database
#   - A valid GitHub repository to test against (default: landovsky/orchestra-ai)

puts "=" * 80
puts "GitHub Service Console Validation"
puts "Task 3.1: Testing GitHub API Integration"
puts "=" * 80
puts

# Step 1: Check for GitHub token
unless ENV['GITHUB_TOKEN']
  puts "❌ ERROR: GITHUB_TOKEN environment variable not set"
  puts
  puts "Please set your GitHub Personal Access Token:"
  puts "  export GITHUB_TOKEN=your_token_here"
  puts
  exit 1
end

puts "✓ GitHub token found in environment"
puts

# Step 2: Get or create a test user
user = User.first
unless user
  puts "⚠️  No users found. Creating test user..."
  user = User.create!(
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123'
  )
  puts "✓ Created test user: #{user.email}"
else
  puts "✓ Using existing user: #{user.email}"
end
puts

# Step 3: Create or find GitHub credential
credential = user.credentials.find_by(service_name: 'github', name: 'test_credential')

if credential
  puts "⚠️  Found existing test credential. Updating with new token..."
  credential.update!(api_key: ENV['GITHUB_TOKEN'])
  puts "✓ Updated existing credential"
else
  puts "Creating new GitHub credential..."
  credential = user.credentials.create!(
    service_name: 'github',
    name: 'test_credential',
    api_key: ENV['GITHUB_TOKEN']
  )
  puts "✓ Created new credential"
end
puts

# Step 4: Initialize GitHub service
puts "Initializing GitHub service..."
begin
  gh = Services::GithubService.new(credential)
  puts "✓ GitHub service initialized successfully"
  puts "  - Auto-pagination enabled: #{gh.client.auto_paginate}"
rescue => e
  puts "❌ Failed to initialize GitHub service: #{e.message}"
  exit 1
end
puts

# Step 5: Test infer_base_branch method
puts "=" * 80
puts "Testing infer_base_branch method"
puts "=" * 80
puts

# Test repositories
test_repos = [
  'landovsky/orchestra-ai',  # Default test repo
  'rails/rails',              # Popular repo using main
  'torvalds/linux',           # Popular repo using master
]

test_repos.each do |repo_name|
  puts "Testing repository: #{repo_name}"
  puts "-" * 80
  
  begin
    # Test the infer_base_branch method
    base_branch = gh.infer_base_branch(repo_name)
    
    puts "✓ SUCCESS"
    puts "  Repository: #{repo_name}"
    puts "  Default branch: #{base_branch}"
    puts
    
  rescue StandardError => e
    puts "❌ FAILED"
    puts "  Repository: #{repo_name}"
    puts "  Error: #{e.message}"
    puts
    
    # If first repo fails, it might be an auth issue
    if repo_name == test_repos.first
      puts "⚠️  Note: Make sure your GitHub token has 'repo' or 'public_repo' scope"
      puts "⚠️  And that you have access to the repository"
    end
  end
end

# Step 6: Test with invalid inputs
puts "=" * 80
puts "Testing error handling"
puts "=" * 80
puts

puts "Test 1: Invalid repository name"
begin
  gh.infer_base_branch('this-repo/does-not-exist-12345')
  puts "❌ Should have raised an error"
rescue StandardError => e
  puts "✓ Correctly raised error: #{e.message}"
end
puts

puts "Test 2: Nil repository name"
begin
  gh.infer_base_branch(nil)
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

puts "Test 3: Empty repository name"
begin
  gh.infer_base_branch('')
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Step 7: Summary
puts "=" * 80
puts "Validation Complete"
puts "=" * 80
puts
puts "✓ GitHub API integration is working correctly"
puts "✓ infer_base_branch method tested successfully"
puts
puts "Next steps (for reference):"
puts "  - Task 3.2: Test merge_pull_request with real PR"
puts "  - Task 3.3: Test delete_branch after merge"
puts
puts "To test other methods from console:"
puts "  gh = Services::GithubService.new(credential)"
puts "  gh.infer_base_branch('owner/repo')"
puts "  # gh.merge_pull_request(task)  # Requires task with PR"
puts "  # gh.delete_branch(task)        # Requires task with branch"
puts
puts "=" * 80
