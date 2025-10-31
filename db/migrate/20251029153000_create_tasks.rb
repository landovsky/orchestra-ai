class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :epic, null: false, foreign_key: true
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :position, null: false
      t.string :cursor_agent_id
      t.string :pr_url
      t.string :branch_name
      t.text :debug_log

      t.timestamps
    end

    add_index :tasks, :status
    add_index :tasks, [:epic_id, :position]
  end
end
