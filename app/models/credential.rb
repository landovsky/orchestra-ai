class Credential < ApplicationRecord
  belongs_to :user

  encrypts :api_key

  validates :service_name, presence: true
  validates :name, presence: true
  validates :api_key, presence: true
  validates :name, uniqueness: { scope: [:user_id, :service_name] }

  scope :github, -> { where(service_name: 'github') }
  scope :cursor_agent, -> { where(service_name: 'cursor_agent') }
end
