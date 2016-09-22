# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160922204016) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_sessions", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "friend_id"
    t.string   "status"
    t.string   "channel_name"
    t.string   "request_type"
    t.datetime "expiry_date"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "devices", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "registration_id"
    t.string   "device_type"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.datetime "authtoken_expiry"
  end

  create_table "errors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "friends", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "friend_id"
    t.string   "friend_status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  create_table "locations", force: :cascade do |t|
    t.integer  "user_id"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "accuracy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pending_notifications", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "sender_id"
    t.string   "category"
    t.string   "payload"
    t.datetime "expiry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary   "read"
  end

  create_table "users", force: :cascade do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "password_hash"
    t.string   "password_salt"
    t.boolean  "email_verification", default: false
    t.string   "verification_code"
    t.string   "api_authtoken"
    t.datetime "authtoken_expiry"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "username"
  end

end
