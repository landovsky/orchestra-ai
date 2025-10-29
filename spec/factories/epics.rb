FactoryBot.define do
  factory :epic do
    association :user
    association :repository
    association :llm_credential, factory: :credential
    association :cursor_agent_credential, factory: :credential

    sequence(:title) { |n| "Epic #{n}" }
    prompt { "Create a new feature with multiple tasks" }
    base_branch { "main" }
    status { :pending }
  end
end
