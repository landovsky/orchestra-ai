class CreateEpics < ActiveRecord::Migration[8.0]
  def change
    create_table :epics do |t|
      t.references :user, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      t.references :llm_credential, null: true, foreign_key: { to_table: :credentials }
      t.references :cursor_agent_credential, null: true, foreign_key: { to_table: :credentials }
      
      t.string :title
      t.text :prompt
      t.string :base_branch
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :epics, :status
  end
end
