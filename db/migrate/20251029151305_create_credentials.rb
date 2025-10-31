# frozen_string_literal: true

class CreateCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :service_name, null: false
      t.string :name, null: false
      t.string :api_key, null: false

      t.timestamps
    end

    add_index :credentials, [:user_id, :service_name, :name], unique: true
  end
end
