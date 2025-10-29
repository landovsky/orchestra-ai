FactoryBot.define do
  factory :task do
    association :epic
    description { "Implement #{Faker::Hacker.verb} #{Faker::Hacker.noun}" }
    sequence(:position) { |n| n }
    status { :pending }
    cursor_agent_id { nil }
    pr_url { nil }
    branch_name { nil }
    debug_log { nil }

    trait :running do
      status { :running }
      cursor_agent_id { "agent-#{SecureRandom.hex(8)}" }
      branch_name { "cursor/#{description.parameterize}-#{SecureRandom.hex(4)}" }
    end

    trait :pr_open do
      status { :pr_open }
      cursor_agent_id { "agent-#{SecureRandom.hex(8)}" }
      branch_name { "cursor/#{description.parameterize}-#{SecureRandom.hex(4)}" }
      pr_url { "https://github.com/example/repo/pull/#{rand(1..999)}" }
    end

    trait :merging do
      status { :merging }
      cursor_agent_id { "agent-#{SecureRandom.hex(8)}" }
      branch_name { "cursor/#{description.parameterize}-#{SecureRandom.hex(4)}" }
      pr_url { "https://github.com/example/repo/pull/#{rand(1..999)}" }
    end

    trait :completed do
      status { :completed }
      cursor_agent_id { "agent-#{SecureRandom.hex(8)}" }
      branch_name { "cursor/#{description.parameterize}-#{SecureRandom.hex(4)}" }
      pr_url { "https://github.com/example/repo/pull/#{rand(1..999)}" }
    end

    trait :failed do
      status { :failed }
      cursor_agent_id { "agent-#{SecureRandom.hex(8)}" }
      branch_name { "cursor/#{description.parameterize}-#{SecureRandom.hex(4)}" }
      debug_log { "Error: #{Faker::Lorem.sentence}" }
    end
  end
end
