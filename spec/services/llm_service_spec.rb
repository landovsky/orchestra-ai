# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::LlmService do
  describe '#initialize' do
    let(:user) { create(:user) }

    context 'with a valid OpenAI credential' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }

      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service).to be_a(Services::LlmService)
        expect(service.credential).to eq(credential)
        expect(service.api_key).to eq(credential.api_key)
        expect(service.service_name).to eq('openai')
      end
    end

    context 'with a valid Claude/Anthropic credential' do
      let(:credential) { create(:credential, user: user, service_name: 'claude') }

      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service.service_name).to eq('claude')
      end
    end

    context 'with a valid Anthropic credential' do
      let(:credential) { create(:credential, user: user, service_name: 'anthropic') }

      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service.service_name).to eq('anthropic')
      end
    end

    context 'with a valid Gemini credential' do
      let(:credential) { create(:credential, user: user, service_name: 'gemini') }

      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service.service_name).to eq('gemini')
      end
    end

    context 'with an invalid credential' do
      it 'raises ArgumentError when credential is nil' do
        expect {
          described_class.new(nil)
        }.to raise_error(ArgumentError, 'Credential cannot be nil')
      end

      it 'raises ArgumentError when credential has no api_key' do
        credential_without_key = build(:credential, user: user, api_key: nil)
        
        expect {
          described_class.new(credential_without_key)
        }.to raise_error(ArgumentError, 'Credential must have an api_key')
      end

      it 'raises ArgumentError when credential has blank api_key' do
        credential_with_blank_key = build(:credential, user: user, api_key: '')
        
        expect {
          described_class.new(credential_with_blank_key)
        }.to raise_error(ArgumentError, 'Credential must have an api_key')
      end

      it 'raises ArgumentError when credential has no service_name' do
        credential = build(:credential, user: user, service_name: nil)
        
        expect {
          described_class.new(credential)
        }.to raise_error(ArgumentError, 'Credential must have a service_name')
      end

      it 'raises ArgumentError when credential has blank service_name' do
        credential = build(:credential, user: user, service_name: '')
        
        expect {
          described_class.new(credential)
        }.to raise_error(ArgumentError, 'Credential must have a service_name')
      end

      it 'raises ArgumentError for unsupported service' do
        credential = build(:credential, user: user, service_name: 'unsupported_llm')
        
        expect {
          described_class.new(credential)
        }.to raise_error(ArgumentError, /Unsupported LLM service: unsupported_llm/)
      end
    end
  end

  describe '#generate_spec' do
    let(:user) { create(:user) }
    let(:prompt) { 'Build a user authentication system with email/password login' }
    let(:base_branch) { 'main' }

    context 'with invalid parameters' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }
      let(:service) { described_class.new(credential) }

      it 'raises ArgumentError when prompt is nil' do
        expect {
          service.generate_spec(nil, base_branch)
        }.to raise_error(ArgumentError, 'prompt cannot be blank')
      end

      it 'raises ArgumentError when prompt is blank' do
        expect {
          service.generate_spec('', base_branch)
        }.to raise_error(ArgumentError, 'prompt cannot be blank')
      end

      it 'raises ArgumentError when prompt is whitespace only' do
        expect {
          service.generate_spec('   ', base_branch)
        }.to raise_error(ArgumentError, 'prompt cannot be blank')
      end

      it 'raises ArgumentError when base_branch is nil' do
        expect {
          service.generate_spec(prompt, nil)
        }.to raise_error(ArgumentError, 'base_branch cannot be blank')
      end

      it 'raises ArgumentError when base_branch is blank' do
        expect {
          service.generate_spec(prompt, '')
        }.to raise_error(ArgumentError, 'base_branch cannot be blank')
      end

      it 'raises ArgumentError when base_branch is whitespace only' do
        expect {
          service.generate_spec(prompt, '   ')
        }.to raise_error(ArgumentError, 'base_branch cannot be blank')
      end
    end

    context 'with OpenAI credential (stub)' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }
      let(:service) { described_class.new(credential) }

      before do
        # Mock the OpenAI API call to return stub
        allow(service).to receive(:generate_spec_openai).and_return(
          service.send(:generate_spec_stub, prompt, base_branch)
        )
      end

      it 'returns a hash with tasks array' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('tasks')
        expect(result['tasks']).to be_an(Array)
        expect(result['tasks']).not_to be_empty
      end

      it 'includes prompt context in generated tasks' do
        result = service.generate_spec(prompt, base_branch)
        
        tasks = result['tasks']
        expect(tasks.first).to include(prompt)
      end

      it 'includes base_branch context in generated tasks' do
        result = service.generate_spec(prompt, base_branch)
        
        tasks = result['tasks']
        expect(tasks.last).to include(base_branch)
      end

      it 'generates multiple tasks' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result['tasks'].length).to be >= 3
      end
    end

    context 'with Claude/Anthropic credential (stub)' do
      let(:credential) { create(:credential, user: user, service_name: 'claude') }
      let(:service) { described_class.new(credential) }

      before do
        # Mock the Anthropic API call to return stub
        allow(service).to receive(:generate_spec_anthropic).and_return(
          service.send(:generate_spec_stub, prompt, base_branch)
        )
      end

      it 'returns a hash with tasks array' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('tasks')
        expect(result['tasks']).to be_an(Array)
      end

      it 'generates tasks with Claude service' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result['tasks']).not_to be_empty
        expect(result['tasks'].first).to be_a(String)
      end
    end

    context 'with Anthropic credential (stub)' do
      let(:credential) { create(:credential, user: user, service_name: 'anthropic') }
      let(:service) { described_class.new(credential) }

      before do
        # Mock the Anthropic API call to return stub
        allow(service).to receive(:generate_spec_anthropic).and_return(
          service.send(:generate_spec_stub, prompt, base_branch)
        )
      end

      it 'returns a hash with tasks array' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('tasks')
      end
    end

    context 'with Gemini credential (stub)' do
      let(:credential) { create(:credential, user: user, service_name: 'gemini') }
      let(:service) { described_class.new(credential) }

      it 'returns a stubbed response' do
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('tasks')
        expect(result['tasks']).to be_an(Array)
        expect(result['tasks']).not_to be_empty
      end
    end

    context 'with different base branches' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }
      let(:service) { described_class.new(credential) }

      before do
        allow(service).to receive(:generate_spec_openai).and_return(
          service.send(:generate_spec_stub, prompt, base_branch)
        )
      end

      it 'handles main branch' do
        result = service.generate_spec(prompt, 'main')
        
        expect(result['tasks']).not_to be_empty
      end

      it 'handles master branch' do
        result = service.generate_spec(prompt, 'master')
        
        expect(result['tasks']).not_to be_empty
      end

      it 'handles feature branches' do
        result = service.generate_spec(prompt, 'feature/epic-123')
        
        expect(result['tasks']).not_to be_empty
      end
    end

    context 'with complex prompts' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }
      let(:service) { described_class.new(credential) }

      before do
        allow(service).to receive(:generate_spec_openai).and_call_original
        allow(service).to receive(:post_to_openai).and_raise(StandardError.new('API Error'))
      end

      it 'handles multi-line prompts' do
        multi_line_prompt = <<~PROMPT
          Build a user authentication system:
          - Email/password login
          - OAuth integration
          - Session management
        PROMPT

        result = service.generate_spec(multi_line_prompt, base_branch)
        
        expect(result['tasks']).not_to be_empty
      end

      it 'handles prompts with special characters' do
        special_prompt = 'Add user auth with OAuth2 & JWT tokens (secure) - v2.0'
        
        result = service.generate_spec(special_prompt, base_branch)
        
        expect(result['tasks']).not_to be_empty
      end

      it 'handles long prompts' do
        long_prompt = 'A' * 1000
        
        result = service.generate_spec(long_prompt, base_branch)
        
        expect(result['tasks']).not_to be_empty
      end
    end

    context 'when API errors occur' do
      let(:credential) { create(:credential, user: user, service_name: 'openai') }
      let(:service) { described_class.new(credential) }

      it 'falls back to stub on OpenAI API error' do
        allow(service).to receive(:post_to_openai).and_raise(StandardError.new('API Error'))
        
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result['tasks']).not_to be_empty
      end

      it 'falls back to stub on Anthropic API error' do
        credential = create(:credential, user: user, service_name: 'claude')
        service = described_class.new(credential)
        allow(service).to receive(:post_to_anthropic).and_raise(StandardError.new('API Error'))
        
        result = service.generate_spec(prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result['tasks']).not_to be_empty
      end
    end
  end

  describe 'private methods' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'openai') }
    let(:service) { described_class.new(credential) }
    let(:prompt) { 'Build user authentication' }
    let(:base_branch) { 'main' }

    describe '#generate_spec_stub' do
      it 'generates a valid stub response' do
        result = service.send(:generate_spec_stub, prompt, base_branch)
        
        expect(result).to be_a(Hash)
        expect(result['tasks']).to be_an(Array)
        expect(result['tasks'].length).to eq(4)
        expect(result['tasks'].first).to include(prompt)
        expect(result['tasks'].last).to include(base_branch)
      end
    end

    describe '#build_system_prompt' do
      it 'includes the base branch in the prompt' do
        system_prompt = service.send(:build_system_prompt, base_branch)
        
        expect(system_prompt).to include(base_branch)
      end

      it 'includes instructions for JSON format' do
        system_prompt = service.send(:build_system_prompt, base_branch)
        
        expect(system_prompt).to include('JSON')
        expect(system_prompt).to include('"tasks"')
      end

      it 'includes guidelines for task breakdown' do
        system_prompt = service.send(:build_system_prompt, base_branch)
        
        expect(system_prompt).to include('actionable')
        expect(system_prompt).to include('sequential')
      end
    end

    describe '#parse_openai_response' do
      it 'correctly parses a valid OpenAI response' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"choices":[{"message":{"content":"{\"tasks\":[\"Task 1\",\"Task 2\"]}"}}]}'
        )
        
        result = service.send(:parse_openai_response, mock_response)
        
        expect(result).to eq({ 'tasks' => ['Task 1', 'Task 2'] })
      end

      it 'raises StandardError when response has no content' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"choices":[]}'
        )
        
        expect {
          service.send(:parse_openai_response, mock_response)
        }.to raise_error(StandardError, /No content in OpenAI response/)
      end

      it 'raises StandardError when JSON parsing fails' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: 'Invalid JSON'
        )
        
        expect {
          service.send(:parse_openai_response, mock_response)
        }.to raise_error(StandardError, /Failed to parse/)
      end
    end

    describe '#parse_anthropic_response' do
      it 'correctly parses a valid Anthropic response' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"content":[{"text":"{\"tasks\":[\"Task 1\",\"Task 2\"]}"}]}'
        )
        
        result = service.send(:parse_anthropic_response, mock_response)
        
        expect(result).to eq({ 'tasks' => ['Task 1', 'Task 2'] })
      end

      it 'raises StandardError when response has no content' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: '{"content":[]}'
        )
        
        expect {
          service.send(:parse_anthropic_response, mock_response)
        }.to raise_error(StandardError, /No content in Anthropic response/)
      end

      it 'raises StandardError when JSON parsing fails' do
        mock_response = instance_double(
          Net::HTTPSuccess,
          body: 'Invalid JSON'
        )
        
        expect {
          service.send(:parse_anthropic_response, mock_response)
        }.to raise_error(StandardError, /Failed to parse/)
      end
    end

    describe '#extract_error_message' do
      it 'extracts error from JSON body' do
        mock_response = instance_double(
          Net::HTTPBadRequest,
          body: '{"error":"Invalid request"}'
        )
        
        result = service.send(:extract_error_message, mock_response)
        
        expect(result).to eq('Invalid request')
      end

      it 'extracts message from JSON body' do
        mock_response = instance_double(
          Net::HTTPBadRequest,
          body: '{"message":"Bad input"}'
        )
        
        result = service.send(:extract_error_message, mock_response)
        
        expect(result).to eq('Bad input')
      end

      it 'returns raw body when JSON parsing fails' do
        mock_response = instance_double(
          Net::HTTPBadRequest,
          body: 'Plain text error'
        )
        
        result = service.send(:extract_error_message, mock_response)
        
        expect(result).to eq('Plain text error')
      end
    end
  end

  describe 'constants' do
    it 'defines the correct OpenAI API endpoint' do
      expect(Services::LlmService::OPENAI_API_ENDPOINT).to eq('https://api.openai.com/v1/chat/completions')
    end

    it 'defines the correct Anthropic API endpoint' do
      expect(Services::LlmService::ANTHROPIC_API_ENDPOINT).to eq('https://api.anthropic.com/v1/messages')
    end

    it 'defines supported services' do
      expect(Services::LlmService::SUPPORTED_SERVICES).to include('openai', 'claude', 'anthropic', 'gemini')
    end
  end
end
