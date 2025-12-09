class CreateNotVerifiedAdvisorySheets < ActiveRecord::Migration[8.0]
  def change
    create_table :not_verified_advisory_sheets do |t|
      t.string :recording, null: false
      t.text :body, null: false
      t.references :auditor, foreign_key: true
      t.string :original_filename

      t.timestamps
    end

    add_index :not_verified_advisory_sheets, :recording
  end
end
