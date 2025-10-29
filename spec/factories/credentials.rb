FactoryBot.define do
  factory :credential do
    association :user

    service_name { "github" }
    name { "credential-#{SecureRandom.hex(4)}" }
    api_key { "test-api-key-#{SecureRandom.hex(16)}" }
  end
end
