FactoryBot.define do
  factory :repository do
    association :user
    association :github_credential, factory: :credential

    name { "repo-#{SecureRandom.hex(4)}" }
    github_url { "https://github.com/user/#{name}" }
  end
end
