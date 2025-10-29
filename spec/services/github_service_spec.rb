# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::GithubService do
  describe '#initialize' do
    let(:user) { create(:user) }
    let(:credential) { create(:credential, user: user, service_name: 'github') }

    context 'with a valid credential' do
      it 'successfully initializes the service' do
        service = described_class.new(credential)
        
        expect(service).to be_a(Services::GithubService)
        expect(service.credential).to eq(credential)
        expect(service.client).to be_a(Octokit::Client)
      end

      it 'configures the Octokit client with the correct access token' do
        service = described_class.new(credential)
        
        expect(service.client.access_token).to eq(credential.api_key)
      end

      it 'enables auto_paginate on the Octokit client' do
        service = described_class.new(credential)
        
        expect(service.client.auto_paginate).to be true
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
    end
  end
end
