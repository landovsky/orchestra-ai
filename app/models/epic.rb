class Epic < ApplicationRecord
  belongs_to :user
  belongs_to :repository
  belongs_to :llm_credential, class_name: 'Credential', optional: true
  belongs_to :cursor_agent_credential, class_name: 'Credential', optional: true
  
  has_many :tasks, -> { order(position: :asc) }, dependent: :destroy

  enum :status, {
    pending: 0,
    generating_spec: 1,
    running: 2,
    paused: 3,
    completed: 4,
    failed: 5
  }, default: :pending

  validates :title, presence: true
  validates :repository, presence: true
  validates :user, presence: true
end
