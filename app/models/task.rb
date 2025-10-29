class Task < ApplicationRecord
  belongs_to :epic

  enum :status, {
    pending: 0,
    running: 1,
    pr_open: 2,
    merging: 3,
    completed: 4,
    failed: 5
  }, default: :pending

  validates :description, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :epic, presence: true

  scope :ordered, -> { order(position: :asc) }
end
