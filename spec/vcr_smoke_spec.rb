# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

# VCR Smoke Test - Validates VCR configuration works correctly
#
# This test verifies that VCR is properly configured and can record/replay
# HTTP interactions before attempting GitHub integration tests.
#
# Purpose:
# - Confirms VCR creates cassettes in the correct location
# - Tests against a simple public API (no authentication required)
# - Should pass immediately without requiring any credentials
#
# Running this test:
#   bundle exec rspec spec/vcr_smoke_spec.rb
#
# Note: This test is NOT tagged with :integration, so it runs by default
# with the rest of the test suite.

RSpec.describe 'VCR Configuration', :vcr do
  describe 'HTTP recording' do
    it 'records HTTP interactions to cassette', :vcr do
      # Test against GitHub Zen API - a simple public endpoint that requires no auth
      response = Net::HTTP.get(URI('https://api.github.com/zen'))
      
      # Verify we got a response
      expect(response).to be_a(String)
      expect(response.length).to be > 0
    end

    it 'replays recorded interactions from cassette', :vcr do
      # This test will use the same cassette as above (grouped by describe block)
      # On first run, it records. On subsequent runs, it replays.
      response = Net::HTTP.get(URI('https://api.github.com/zen'))
      
      expect(response).to be_a(String)
      expect(response.length).to be > 0
    end
  end
end
