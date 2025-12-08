class CreateAudits < ActiveRecord::Migration[8.0]
  def change
    create_table :audits do |t|
      t.references :consultation_sheet, null: false, foreign_key: true
      t.references :auditor, null: false, foreign_key: true
      t.jsonb :analysis

      t.timestamps
    end
  end
end
