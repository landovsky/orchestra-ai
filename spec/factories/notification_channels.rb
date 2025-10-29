FactoryBot.define do
  factory :notification_channel do
    user
    service_name { 'telegram' }
    sequence(:channel_id) { |n| "channel_#{n}" }
  end
end
