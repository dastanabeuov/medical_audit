class ReferencesDoctorToVerifiedAdvisorySheets < ActiveRecord::Migration[8.0]
  def change
   create_table :relationships_doctor_and_verified_advisory_sheets do |t|
      t.references :verified_advisory_sheet, null: false, foreign_key: true
      t.references :doctor, null: false, foreign_key: true

      t.timestamps
    end
  end
end
