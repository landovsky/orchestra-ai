class NotificationChannel < ApplicationRecord
  belongs_to :user

  validates :service_name, presence: true
  validates :channel_id, presence: true
  validates :channel_id, uniqueness: { scope: [:user_id, :service_name] }
end
