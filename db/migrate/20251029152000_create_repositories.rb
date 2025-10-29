# frozen_string_literal: true

class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :github_url, null: false
      t.references :github_credential, null: false, foreign_key: { to_table: :credentials }

      t.timestamps
    end

    add_index :repositories, [:user_id, :name], unique: true
  end
end
