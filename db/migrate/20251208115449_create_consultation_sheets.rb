class CreateConsultationSheets < ActiveRecord::Migration[8.0]
  def change
    create_table :consultation_sheets, if_not_exists: true do |t|
      t.string :patient_name
      t.string :patient_id
      t.string :diagnosis
      t.text :content
      t.integer :status
      t.decimal :score
      t.integer :risk_level
      t.text :raw_file
      t.jsonb :findings

      t.timestamps
    end
  end
end
