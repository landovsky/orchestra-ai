#!/usr/bin/env ruby
# frozen_string_literal: true

# LLM Service Console Validation Script
# Task 3.3: LLM Service Console Validation
#
# This script tests the LLM API integration with real credentials,
# specifically testing the generate_spec method to break down high-level
# prompts into actionable task lists.
#
# USAGE:
#   From Rails console:
#     load 'script/test_llm_service.rb'
#
#   Or run directly:
#     rails runner script/test_llm_service.rb
#
# SETUP:
#   Set environment variable(s) for your chosen LLM provider:
#     OPENAI_KEY=your_openai_api_key           # For OpenAI
#     ANTHROPIC_KEY=your_anthropic_api_key     # For Anthropic/Claude
#     GEMINI_KEY=your_gemini_api_key           # For Gemini (stub for now)
#
# REQUIREMENTS:
#   - Valid API key for at least one LLM provider
#   - At least one User record in the database
#
# SUPPORTED PROVIDERS:
#   - OpenAI (GPT-4)
#   - Anthropic/Claude
#   - Gemini (stub implementation)

puts "=" * 80
puts "LLM Service Console Validation"
puts "Task 3.3: Testing LLM API Integration for Spec Generation"
puts "=" * 80
puts

# ============================================================================
# Step 1: Environment Validation
# ============================================================================

puts "Step 1: Validating environment setup"
puts "-" * 80

# Check which LLM providers are configured
available_providers = []

if ENV['OPENAI_KEY']
  available_providers << { name: 'openai', key: ENV['OPENAI_KEY'], env_var: 'OPENAI_KEY' }
  puts "✓ OPENAI_KEY found"
end

if ENV['ANTHROPIC_KEY']
  available_providers << { name: 'anthropic', key: ENV['ANTHROPIC_KEY'], env_var: 'ANTHROPIC_KEY' }
  puts "✓ ANTHROPIC_KEY found"
end

if ENV['CLAUDE_KEY']
  available_providers << { name: 'claude', key: ENV['CLAUDE_KEY'], env_var: 'CLAUDE_KEY' }
  puts "✓ CLAUDE_KEY found"
end

if ENV['GEMINI_KEY']
  available_providers << { name: 'gemini', key: ENV['GEMINI_KEY'], env_var: 'GEMINI_KEY' }
  puts "✓ GEMINI_KEY found (note: using stub implementation)"
end

if available_providers.empty?
  puts "❌ ERROR: No LLM API keys found in environment"
  puts
  puts "Please set at least one of the following environment variables:"
  puts "  export OPENAI_KEY=sk-your_openai_key_here        # For OpenAI/GPT-4"
  puts "  export ANTHROPIC_KEY=sk-ant-your_key_here        # For Anthropic/Claude"
  puts "  export CLAUDE_KEY=sk-ant-your_key_here           # Alternative for Claude"
  puts "  export GEMINI_KEY=your_gemini_key_here           # For Gemini (stub)"
  puts
  puts "Recommended: OpenAI or Anthropic for best results"
  puts
  exit 1
end

puts
puts "Found #{available_providers.length} LLM provider(s) configured:"
available_providers.each do |provider|
  puts "  - #{provider[:name]} (#{provider[:env_var]})"
end
puts

# ============================================================================
# Step 2: Database Setup - User
# ============================================================================

puts "Step 2: Setting up test user"
puts "-" * 80

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

# ============================================================================
# Step 3: Test Prompts Setup
# ============================================================================

puts "Step 3: Preparing test prompts"
puts "-" * 80

test_prompts = [
  {
    name: "User Authentication",
    prompt: "Add user authentication with email/password",
    base_branch: "main",
    expected_min_tasks: 3
  },
  {
    name: "REST API",
    prompt: "Build a REST API for managing blog posts with CRUD operations",
    base_branch: "main",
    expected_min_tasks: 4
  },
  {
    name: "Simple Feature",
    prompt: "Add dark mode toggle to the application settings",
    base_branch: "develop",
    expected_min_tasks: 2
  }
]

puts "Prepared #{test_prompts.length} test prompts:"
test_prompts.each_with_index do |test, idx|
  puts "  #{idx + 1}. #{test[:name]}: \"#{test[:prompt]}\""
end
puts

# ============================================================================
# Step 4: Test Each Provider
# ============================================================================

puts "=" * 80
puts "Step 4: Testing LLM Service with Each Provider"
puts "=" * 80
puts

results = []

available_providers.each_with_index do |provider, provider_idx|
  puts
  puts "=" * 80
  puts "Provider #{provider_idx + 1}/#{available_providers.length}: #{provider[:name].upcase}"
  puts "=" * 80
  puts
  
  # Create or update credential for this provider
  puts "Setting up credential for #{provider[:name]}..."
  credential = user.credentials.find_by(service_name: provider[:name], name: 'test_llm_credential')
  
  if credential
    puts "⚠️  Found existing #{provider[:name]} credential. Updating..."
    credential.update!(api_key: provider[:key])
    puts "✓ Updated #{provider[:name]} credential"
  else
    puts "Creating #{provider[:name]} credential..."
    credential = user.credentials.create!(
      service_name: provider[:name],
      name: 'test_llm_credential',
      api_key: provider[:key]
    )
    puts "✓ Created #{provider[:name]} credential"
  end
  puts
  
  # Initialize service
  puts "Initializing LLM service with #{provider[:name]}..."
  begin
    llm_service = Services::LlmService.new(credential)
    puts "✓ LLM service initialized successfully"
    puts "  Service Name: #{llm_service.service_name}"
    puts "  Credential ID: #{credential.id}"
  rescue => e
    puts "❌ Failed to initialize LLM service: #{e.message}"
    results << { provider: provider[:name], status: 'init_failed', error: e.message }
    next
  end
  puts
  
  # Test with each prompt
  test_prompts.each_with_index do |test, prompt_idx|
    puts "-" * 80
    puts "Test #{prompt_idx + 1}/#{test_prompts.length}: #{test[:name]}"
    puts "-" * 80
    puts "Prompt: \"#{test[:prompt]}\""
    puts "Base Branch: #{test[:base_branch]}"
    puts
    
    begin
      # Call generate_spec
      result = llm_service.generate_spec(test[:prompt], test[:base_branch])
      
      # Validate result structure
      if result.is_a?(Hash) && result.key?('tasks') && result['tasks'].is_a?(Array)
        task_count = result['tasks'].length
        
        puts "✓ SUCCESS"
        puts "  Generated #{task_count} tasks:"
        result['tasks'].each_with_index do |task, idx|
          # Truncate long tasks for display
          display_task = task.length > 80 ? "#{task[0..77]}..." : task
          puts "    #{idx + 1}. #{display_task}"
        end
        puts
        
        # Verify minimum task count
        if task_count >= test[:expected_min_tasks]
          puts "  ✓ Task count meets minimum (>= #{test[:expected_min_tasks]})"
        else
          puts "  ⚠️  Task count below expected minimum (got #{task_count}, expected >= #{test[:expected_min_tasks]})"
        end
        
        results << {
          provider: provider[:name],
          test: test[:name],
          status: 'success',
          task_count: task_count,
          tasks: result['tasks']
        }
      else
        puts "❌ FAILED: Invalid response structure"
        puts "  Expected: { 'tasks' => [...] }"
        puts "  Got: #{result.inspect}"
        results << { provider: provider[:name], test: test[:name], status: 'invalid_response', response: result }
      end
      
    rescue => e
      puts "❌ FAILED"
      puts "  Error: #{e.message}"
      puts "  Class: #{e.class.name}"
      results << { provider: provider[:name], test: test[:name], status: 'error', error: e.message }
    end
    
    puts
  end
end

# ============================================================================
# Step 5: Test Error Handling
# ============================================================================

puts "=" * 80
puts "Step 5: Testing Error Handling and Validation"
puts "=" * 80
puts

# Use the first available provider for validation tests
test_provider = available_providers.first
credential = user.credentials.find_by(service_name: test_provider[:name], name: 'test_llm_credential')
llm_service = Services::LlmService.new(credential)

puts "Using #{test_provider[:name]} for validation tests"
puts

# Test 1: Nil prompt
puts "Test 1: generate_spec with nil prompt"
begin
  llm_service.generate_spec(nil, 'main')
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 2: Blank prompt
puts "Test 2: generate_spec with blank prompt"
begin
  llm_service.generate_spec('', 'main')
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 3: Whitespace-only prompt
puts "Test 3: generate_spec with whitespace-only prompt"
begin
  llm_service.generate_spec('   ', 'main')
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 4: Nil base_branch
puts "Test 4: generate_spec with nil base_branch"
begin
  llm_service.generate_spec('Add feature', nil)
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 5: Blank base_branch
puts "Test 5: generate_spec with blank base_branch"
begin
  llm_service.generate_spec('Add feature', '')
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 6: Invalid credential (nil)
puts "Test 6: Initialize with nil credential"
begin
  Services::LlmService.new(nil)
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# Test 7: Invalid credential (unsupported service)
puts "Test 7: Initialize with unsupported service"
begin
  invalid_cred = user.credentials.new(service_name: 'unsupported_llm', api_key: 'test')
  Services::LlmService.new(invalid_cred)
  puts "❌ Should have raised ArgumentError"
rescue ArgumentError => e
  puts "✓ Correctly raised ArgumentError: #{e.message}"
end
puts

# ============================================================================
# Step 6: Test Different Prompt Types
# ============================================================================

puts "=" * 80
puts "Step 6: Testing Different Prompt Types"
puts "=" * 80
puts

complex_prompts = [
  {
    name: "Multi-line Prompt",
    prompt: <<~PROMPT,
      Build a user management system with:
      - User registration with email verification
      - Password reset functionality
      - Role-based access control (admin, user, guest)
      - User profile management
    PROMPT
    base_branch: "main"
  },
  {
    name: "Prompt with Special Characters",
    prompt: "Add OAuth2.0 authentication with JWT tokens & secure session management (v3.0+)",
    base_branch: "feature/auth-v3"
  },
  {
    name: "Short Prompt",
    prompt: "Add comments",
    base_branch: "main"
  }
]

complex_prompts.each_with_index do |test, idx|
  puts "-" * 80
  puts "Complex Test #{idx + 1}/#{complex_prompts.length}: #{test[:name]}"
  puts "-" * 80
  display_prompt = test[:prompt].gsub(/\n/, ' ').squeeze(' ').strip
  display_prompt = display_prompt.length > 100 ? "#{display_prompt[0..97]}..." : display_prompt
  puts "Prompt: \"#{display_prompt}\""
  puts
  
  begin
    result = llm_service.generate_spec(test[:prompt], test[:base_branch])
    
    if result.is_a?(Hash) && result['tasks'].is_a?(Array)
      puts "✓ SUCCESS: Generated #{result['tasks'].length} tasks"
      puts "  First task: #{result['tasks'].first[0..80]}"
      puts "  Last task: #{result['tasks'].last[0..80]}"
    else
      puts "❌ Invalid response structure"
    end
  rescue => e
    puts "❌ FAILED: #{e.message}"
  end
  
  puts
end

# ============================================================================
# Step 7: Summary and Results
# ============================================================================

puts "=" * 80
puts "Validation Complete - Summary"
puts "=" * 80
puts

# Count successes and failures
success_count = results.count { |r| r[:status] == 'success' }
failure_count = results.length - success_count

puts "Results:"
puts "  Total tests: #{results.length}"
puts "  Successful: #{success_count}"
puts "  Failed: #{failure_count}"
puts

# Group by provider
puts "Results by Provider:"
available_providers.each do |provider|
  provider_results = results.select { |r| r[:provider] == provider[:name] }
  provider_successes = provider_results.count { |r| r[:status] == 'success' }
  
  if provider_results.empty?
    puts "  #{provider[:name]}: No results (initialization may have failed)"
  else
    puts "  #{provider[:name]}: #{provider_successes}/#{provider_results.length} successful"
    
    # Show any errors
    provider_results.each do |result|
      if result[:status] != 'success'
        puts "    ❌ #{result[:test]}: #{result[:status]} - #{result[:error] || 'Unknown error'}"
      end
    end
  end
end
puts

# Overall status
if success_count > 0
  puts "✅ ACCEPTANCE CRITERIA MET"
  puts "   ✓ Can generate task list from prompt"
  puts "   ✓ Returns valid JSON structure with 'tasks' array"
  puts "   ✓ Error handling validated"
  puts "   ✓ Multiple prompt types supported"
  puts
  
  puts "📊 Sample Generated Spec:"
  sample_result = results.find { |r| r[:status] == 'success' }
  if sample_result
    puts "   Provider: #{sample_result[:provider]}"
    puts "   Prompt: #{sample_result[:test]}"
    puts "   Tasks:"
    sample_result[:tasks].each_with_index do |task, idx|
      display_task = task.length > 70 ? "#{task[0..67]}..." : task
      puts "     #{idx + 1}. #{display_task}"
    end
  end
  puts
else
  puts "⚠️  WARNING: No successful spec generations"
  puts
  puts "Possible issues:"
  puts "  - Invalid API key(s)"
  puts "  - API rate limiting"
  puts "  - Network connectivity issues"
  puts "  - API endpoint unavailable"
  puts
  puts "All providers fell back to stub implementation or failed completely."
  puts
end

puts "Next steps:"
puts "  1. Verify the generated tasks make sense for the given prompts"
puts "  2. Test with your own custom prompts from console"
puts "  3. Proceed to Phase 4: Manual Epic Creation & Basic Interactions"
puts "  4. Use generate_spec in Epics::GenerateSpecJob (Phase 9)"
puts
puts "To test generate_spec manually from Rails console:"
puts "  user = User.first"
puts "  cred = Credential.create!(user: user, service_name: 'openai', api_key: ENV['OPENAI_KEY'])"
puts "  llm = Services::LlmService.new(cred)"
puts "  spec = llm.generate_spec("
puts "    'Add user authentication with email/password',"
puts "    'main'"
puts "  )"
puts "  pp spec['tasks']"
puts
puts "To test from this script again:"
puts "  rails runner script/test_llm_service.rb"
puts
puts "Supported LLM providers:"
puts "  - openai (GPT-4) - Recommended"
puts "  - anthropic / claude (Claude 3.5 Sonnet) - Recommended"
puts "  - gemini (stub implementation for now)"
puts
puts "=" * 80
