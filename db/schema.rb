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

ActiveRecord::Schema[8.0].define(version: 2025_12_15_063329) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "auditors", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "position"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_auditors_on_confirmation_token", unique: true
    t.index ["email"], name: "index_auditors_on_email", unique: true
    t.index ["reset_password_token"], name: "index_auditors_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_auditors_on_unlock_token", unique: true
  end

  create_table "doctors", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "specialization"
    t.bigint "main_doctor_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_doctors_on_confirmation_token", unique: true
    t.index ["email"], name: "index_doctors_on_email", unique: true
    t.index ["main_doctor_id"], name: "index_doctors_on_main_doctor_id"
    t.index ["reset_password_token"], name: "index_doctors_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_doctors_on_unlock_token", unique: true
  end

  create_table "main_doctors", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "department"
    t.string "specialization"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_main_doctors_on_confirmation_token", unique: true
    t.index ["email"], name: "index_main_doctors_on_email", unique: true
    t.index ["reset_password_token"], name: "index_main_doctors_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_main_doctors_on_unlock_token", unique: true
  end

  create_table "mkbs", force: :cascade do |t|
    t.string "code", null: false
    t.string "title", null: false
    t.text "description"
    t.string "source_file"
    t.vector "embedding", limit: 768
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_mkbs_on_code", unique: true
    t.index ["title"], name: "index_mkbs_on_title"
  end

  create_table "not_verified_advisory_sheets", force: :cascade do |t|
    t.string "recording", null: false
    t.text "body", null: false
    t.bigint "auditor_id"
    t.string "original_filename"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditor_id"], name: "index_not_verified_advisory_sheets_on_auditor_id"
    t.index ["recording"], name: "index_not_verified_advisory_sheets_on_recording"
  end

  create_table "protocols", force: :cascade do |t|
    t.string "title", null: false
    t.string "code"
    t.text "content", null: false
    t.string "source_file"
    t.vector "embedding", limit: 768
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_protocols_on_code"
    t.index ["title"], name: "index_protocols_on_title"
  end

  create_table "verified_advisory_sheets", force: :cascade do |t|
    t.string "recording", null: false
    t.text "body", null: false
    t.integer "status", default: 0, null: false
    t.text "verification_result"
    t.text "recommendations"
    t.bigint "auditor_id"
    t.string "original_filename"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditor_id"], name: "index_verified_advisory_sheets_on_auditor_id"
    t.index ["recording"], name: "index_verified_advisory_sheets_on_recording"
    t.index ["status"], name: "index_verified_advisory_sheets_on_status"
  end

  add_foreign_key "doctors", "main_doctors"
  add_foreign_key "not_verified_advisory_sheets", "auditors"
  add_foreign_key "verified_advisory_sheets", "auditors"
end
