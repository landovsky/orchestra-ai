# frozen_string_literal: true

module Telegram
  class SendMessageJob < ApplicationJob
    queue_as :default

    # Sends a message to a Telegram chat via the Telegram Bot API
    #
    # @param chat_id [String, Integer] The Telegram chat ID to send the message to
    # @param message [String] The message text to send
    # @param parse_mode [String] Optional parse mode (e.g., 'Markdown', 'HTML')
    #
    # @example
    #   Telegram::SendMessageJob.perform_async('123456789', 'Hello from the bot!')
    #
    def perform(chat_id, message, parse_mode: nil)
      raise ArgumentError, 'chat_id cannot be nil or blank' if chat_id.to_s.strip.empty?
      raise ArgumentError, 'message cannot be nil or blank' if message.to_s.strip.empty?
      raise StandardError, 'TELEGRAM_BOT_TOKEN environment variable is not set' if bot_token.nil? || bot_token.strip.empty?

      send_telegram_message(chat_id, message, parse_mode)
    end

    private

    def bot_token
      ENV['TELEGRAM_BOT_TOKEN']
    end

    def telegram_api_url
      "https://api.telegram.org/bot#{bot_token}/sendMessage"
    end

    def send_telegram_message(chat_id, message, parse_mode)
      payload = {
        chat_id: chat_id.to_s,
        text: message
      }
      payload[:parse_mode] = parse_mode if parse_mode.present?

      response = HTTParty.post(
        telegram_api_url,
        body: payload.to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 10
      )

      handle_response(response)
    end

    def handle_response(response)
      parsed_response = JSON.parse(response.body)

      unless response.success?
        error_message = parsed_response.dig('description') || 'Unknown error'
        raise StandardError, "Telegram API error: #{error_message}"
      end

      unless parsed_response['ok']
        error_message = parsed_response.dig('description') || 'Unknown error'
        raise StandardError, "Telegram API returned not ok: #{error_message}"
      end

      parsed_response['result']
    rescue JSON::ParserError => e
      raise StandardError, "Failed to parse Telegram API response: #{e.message}"
    end
  end
end
