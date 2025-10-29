# frozen_string_literal: true

class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :service_name, null: false
      t.string :channel_id, null: false

      t.timestamps
    end

    add_index :notification_channels, [:user_id, :service_name, :channel_id], unique: true,
      name: "index_notification_channels_on_user_service_channel"
  end
end
