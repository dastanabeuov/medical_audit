class CreateVerifiedAdvisorySheets < ActiveRecord::Migration[8.0]
  def change
    create_table :verified_advisory_sheets do |t|
      t.string :recording, null: false
      t.text :body, null: false
      t.integer :status, default: 0, null: false  # enum: red, yellow, green
      t.text :verification_result
      t.text :recommendations
      t.references :auditor, foreign_key: true
      t.string :original_filename
      t.datetime :verified_at

      t.timestamps
    end

    add_index :verified_advisory_sheets, :recording
    add_index :verified_advisory_sheets, :status
  end
end
