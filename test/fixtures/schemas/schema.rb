# frozen_string_literal: true

ActiveRecord::Schema[7.0].define(version: 20_240_601_090_000) do
  create_table "users", force: :cascade do |t|
    t.string  "email",      null: false, limit: 255
    t.string  "name",       null: false, limit: 100
    t.integer "role",       default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.string   "title",      null: false
    t.text     "body"
    t.integer  "user_id",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "post_tags", force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "tag_id",  null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "posts", ["user_id"], name: "index_posts_on_user_id"
end
