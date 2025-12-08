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

ActiveRecord::Schema[8.0].define(version: 2025_12_08_115542) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "audit_batches", force: :cascade do |t|
    t.string "name"
    t.integer "status"
    t.integer "total_sheets"
    t.integer "processed_sheets"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "auditors", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
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

  create_table "audits", force: :cascade do |t|
    t.bigint "consultation_sheet_id", null: false
    t.bigint "auditor_id", null: false
    t.jsonb "analysis"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditor_id"], name: "index_audits_on_auditor_id"
    t.index ["consultation_sheet_id"], name: "index_audits_on_consultation_sheet_id"
  end

  create_table "consultation_sheets", force: :cascade do |t|
    t.string "patient_name"
    t.string "patient_id"
    t.string "diagnosis"
    t.text "content"
    t.integer "status"
    t.decimal "score"
    t.integer "risk_level"
    t.text "raw_file"
    t.jsonb "findings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "doctors", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_doctors_on_email", unique: true
    t.index ["reset_password_token"], name: "index_doctors_on_reset_password_token", unique: true
  end

  create_table "knowledge_documents", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.string "document_type"
    t.string "source"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "main_doctors", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_main_doctors_on_email", unique: true
    t.index ["reset_password_token"], name: "index_main_doctors_on_reset_password_token", unique: true
  end

  add_foreign_key "audits", "auditors"
  add_foreign_key "audits", "consultation_sheets"
end
