# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::SendMessageJob, type: :job do
  let(:chat_id) { '123456789' }
  let(:message) { 'Hello from the bot!' }
  let(:bot_token) { 'test_bot_token_123' }
  let(:telegram_api_url) { "https://api.telegram.org/bot#{bot_token}/sendMessage" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return(bot_token)
  end

  describe '#perform' do
    context 'with valid parameters' do
      let(:successful_response) do
        {
          ok: true,
          result: {
            message_id: 1,
            chat: { id: chat_id.to_i, type: 'private' },
            text: message
          }
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: message }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: successful_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'successfully sends a message to Telegram' do
        result = described_class.new.perform(chat_id, message)

        expect(result).to eq(successful_response[:result].stringify_keys)
      end

      it 'makes a POST request to the Telegram API with correct parameters' do
        described_class.new.perform(chat_id, message)

        expect(WebMock).to have_requested(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: message }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'includes the bot token in the URL' do
        described_class.new.perform(chat_id, message)

        expect(WebMock).to have_requested(:post, telegram_api_url)
      end
    end

    context 'with parse_mode parameter' do
      let(:successful_response) do
        {
          ok: true,
          result: {
            message_id: 1,
            chat: { id: chat_id.to_i, type: 'private' },
            text: message
          }
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: message, parse_mode: 'Markdown' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: successful_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'includes parse_mode in the request when provided' do
        described_class.new.perform(chat_id, message, parse_mode: 'Markdown')

        expect(WebMock).to have_requested(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: message, parse_mode: 'Markdown' }.to_json
          )
      end
    end

    context 'with integer chat_id' do
      let(:integer_chat_id) { 123456789 }
      let(:successful_response) do
        {
          ok: true,
          result: {
            message_id: 1,
            chat: { id: integer_chat_id, type: 'private' },
            text: message
          }
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .with(
            body: { chat_id: integer_chat_id.to_s, text: message }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(
            status: 200,
            body: successful_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'converts integer chat_id to string' do
        described_class.new.perform(integer_chat_id, message)

        expect(WebMock).to have_requested(:post, telegram_api_url)
          .with(
            body: { chat_id: integer_chat_id.to_s, text: message }.to_json
          )
      end
    end

    context 'when chat_id is invalid' do
      it 'raises ArgumentError when chat_id is nil' do
        expect {
          described_class.new.perform(nil, message)
        }.to raise_error(ArgumentError, 'chat_id cannot be nil or blank')
      end

      it 'raises ArgumentError when chat_id is blank string' do
        expect {
          described_class.new.perform('', message)
        }.to raise_error(ArgumentError, 'chat_id cannot be nil or blank')
      end

      it 'raises ArgumentError when chat_id is whitespace only' do
        expect {
          described_class.new.perform('   ', message)
        }.to raise_error(ArgumentError, 'chat_id cannot be nil or blank')
      end
    end

    context 'when message is invalid' do
      it 'raises ArgumentError when message is nil' do
        expect {
          described_class.new.perform(chat_id, nil)
        }.to raise_error(ArgumentError, 'message cannot be nil or blank')
      end

      it 'raises ArgumentError when message is blank string' do
        expect {
          described_class.new.perform(chat_id, '')
        }.to raise_error(ArgumentError, 'message cannot be nil or blank')
      end

      it 'raises ArgumentError when message is whitespace only' do
        expect {
          described_class.new.perform(chat_id, '   ')
        }.to raise_error(ArgumentError, 'message cannot be nil or blank')
      end
    end

    context 'when TELEGRAM_BOT_TOKEN is not set' do
      before do
        allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return(nil)
      end

      it 'raises StandardError' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, 'TELEGRAM_BOT_TOKEN environment variable is not set')
      end
    end

    context 'when TELEGRAM_BOT_TOKEN is blank' do
      before do
        allow(ENV).to receive(:[]).with('TELEGRAM_BOT_TOKEN').and_return('   ')
      end

      it 'raises StandardError' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, 'TELEGRAM_BOT_TOKEN environment variable is not set')
      end
    end

    context 'when Telegram API returns an error' do
      let(:error_response) do
        {
          ok: false,
          error_code: 400,
          description: 'Bad Request: chat not found'
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .to_return(
            status: 400,
            body: error_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises StandardError with the error message' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, 'Telegram API error: Bad Request: chat not found')
      end
    end

    context 'when Telegram API returns ok: false' do
      let(:error_response) do
        {
          ok: false,
          description: 'Invalid chat_id specified'
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .to_return(
            status: 200,
            body: error_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises StandardError with the error message' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, 'Telegram API returned not ok: Invalid chat_id specified')
      end
    end

    context 'when Telegram API returns invalid JSON' do
      before do
        stub_request(:post, telegram_api_url)
          .to_return(
            status: 200,
            body: 'Invalid JSON response',
            headers: { 'Content-Type' => 'text/html' }
          )
      end

      it 'raises StandardError with parse error message' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, /Failed to parse Telegram API response/)
      end
    end

    context 'when Telegram API returns error without description' do
      let(:error_response) do
        {
          ok: false,
          error_code: 500
        }
      end

      before do
        stub_request(:post, telegram_api_url)
          .to_return(
            status: 500,
            body: error_response.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises StandardError with generic error message' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(StandardError, 'Telegram API error: Unknown error')
      end
    end

    context 'when network request times out' do
      before do
        stub_request(:post, telegram_api_url)
          .to_timeout
      end

      it 'raises Net::OpenTimeout' do
        expect {
          described_class.new.perform(chat_id, message)
        }.to raise_error(Net::OpenTimeout)
      end
    end

    context 'with different message types' do
      let(:successful_response) do
        {
          ok: true,
          result: { message_id: 1, chat: { id: chat_id.to_i }, text: message }
        }
      end

      it 'handles messages with special characters' do
        special_message = 'Hello! 🎉 This has émojis & spëcial chars: @#$%'
        
        stub_request(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: special_message }.to_json
          )
          .to_return(
            status: 200,
            body: successful_response.to_json
          )

        expect {
          described_class.new.perform(chat_id, special_message)
        }.not_to raise_error
      end

      it 'handles multi-line messages' do
        multiline_message = "Line 1\nLine 2\nLine 3"
        
        stub_request(:post, telegram_api_url)
          .with(
            body: { chat_id: chat_id, text: multiline_message }.to_json
          )
          .to_return(
            status: 200,
            body: successful_response.to_json
          )

        expect {
          described_class.new.perform(chat_id, multiline_message)
        }.not_to raise_error
      end
    end
  end

  describe 'job enqueueing' do
    it 'can be enqueued' do
      expect {
        described_class.perform_later(chat_id, message)
      }.to have_enqueued_job(described_class).with(chat_id, message)
    end

    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
