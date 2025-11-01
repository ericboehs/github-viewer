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

ActiveRecord::Schema[8.1].define(version: 2025_11_01_042847) do
  create_table "github_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", default: "github.com", null: false
    t.string "label"
    t.text "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "domain"], name: "index_github_tokens_on_user_id_and_domain", unique: true
    t.index ["user_id"], name: "index_github_tokens_on_user_id"
  end

  create_table "issue_comments", force: :cascade do |t|
    t.string "author_avatar_url"
    t.string "author_login"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "github_created_at"
    t.bigint "github_id", null: false
    t.datetime "github_updated_at"
    t.integer "issue_id", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id", "github_id"], name: "index_issue_comments_on_issue_id_and_github_id", unique: true
    t.index ["issue_id"], name: "index_issue_comments_on_issue_id"
  end

  create_table "issues", force: :cascade do |t|
    t.json "assignees", default: []
    t.string "author_avatar_url"
    t.string "author_login"
    t.text "body"
    t.datetime "cached_at"
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.json "labels", default: []
    t.integer "number", null: false
    t.integer "repository_id", null: false
    t.string "state", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "number"], name: "index_issues_on_repository_id_and_number", unique: true
    t.index ["repository_id", "state"], name: "index_issues_on_repository_id_and_state"
    t.index ["repository_id"], name: "index_issues_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "cached_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "full_name", null: false
    t.string "github_domain", default: "github.com", null: false
    t.integer "issue_count", default: 0, null: false
    t.string "name", null: false
    t.integer "open_issue_count", default: 0, null: false
    t.string "owner", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id", null: false
    t.index ["user_id", "github_domain", "owner", "name"], name: "idx_on_user_id_github_domain_owner_name_1c50134333", unique: true
    t.index ["user_id"], name: "index_repositories_on_user_id"
  end

  create_table "repository_assignable_users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "login", null: false
    t.integer "repository_id", null: false
    t.datetime "updated_at", null: false
    t.index ["login"], name: "index_repository_assignable_users_on_login"
    t.index ["repository_id", "login"], name: "index_repository_assignable_users_on_repository_id_and_login", unique: true
    t.index ["repository_id"], name: "index_repository_assignable_users_on_repository_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "github_domain", default: "github.com", null: false
    t.text "github_token"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "github_tokens", "users"
  add_foreign_key "issue_comments", "issues"
  add_foreign_key "issues", "repositories"
  add_foreign_key "repositories", "users"
  add_foreign_key "repository_assignable_users", "repositories"
  add_foreign_key "sessions", "users"
end
