# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_10_29_153500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "credentials", force: :cascade do |t|
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "service_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "service_name", "name"], name: "index_credentials_on_user_id_and_service_name_and_name", unique: true
    t.index ["user_id"], name: "index_credentials_on_user_id"
  end

  create_table "epics", force: :cascade do |t|
    t.string "base_branch"
    t.datetime "created_at", null: false
    t.bigint "cursor_agent_credential_id"
    t.bigint "llm_credential_id"
    t.text "prompt"
    t.bigint "repository_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["cursor_agent_credential_id"], name: "index_epics_on_cursor_agent_credential_id"
    t.index ["llm_credential_id"], name: "index_epics_on_llm_credential_id"
    t.index ["repository_id"], name: "index_epics_on_repository_id"
    t.index ["status"], name: "index_epics_on_status"
    t.index ["user_id"], name: "index_epics_on_user_id"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.string "channel_id", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "service_name", "channel_id"], name: "index_notification_channels_on_user_service_channel", unique: true
    t.index ["user_id"], name: "index_notification_channels_on_user_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "github_credential_id", null: false
    t.string "github_url", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["github_credential_id"], name: "index_repositories_on_github_credential_id"
    t.index ["user_id", "name"], name: "index_repositories_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_repositories_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "branch_name"
    t.datetime "created_at", null: false
    t.string "cursor_agent_id"
    t.text "debug_log"
    t.text "description"
    t.bigint "epic_id", null: false
    t.integer "position", null: false
    t.string "pr_url"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["epic_id", "position"], name: "index_tasks_on_epic_id_and_position"
    t.index ["epic_id"], name: "index_tasks_on_epic_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "credentials", "users"
  add_foreign_key "epics", "credentials", column: "cursor_agent_credential_id"
  add_foreign_key "epics", "credentials", column: "llm_credential_id"
  add_foreign_key "epics", "repositories"
  add_foreign_key "epics", "users"
  add_foreign_key "notification_channels", "users"
  add_foreign_key "repositories", "credentials", column: "github_credential_id"
  add_foreign_key "repositories", "users"
  add_foreign_key "tasks", "epics"
end
