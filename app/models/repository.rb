class Repository < ApplicationRecord
  belongs_to :user
  belongs_to :github_credential, class_name: 'Credential'

  validates :name, presence: true
  validates :github_url, presence: true
  validates :name, uniqueness: { scope: :user_id }
end
