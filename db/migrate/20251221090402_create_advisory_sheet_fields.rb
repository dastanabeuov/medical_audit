class CreateAdvisorySheetFields < ActiveRecord::Migration[8.0]
  def change
    create_table :advisory_sheet_fields do |t|
      t.references :verified_advisory_sheet, null: false, foreign_key: true, index: { unique: true }

      # Ключевые поля консультативного листа
      t.text :complaints              # Жалобы
      t.text :anamnesis_morbi         # Anamnesis morbi
      t.text :anamnesis_vitae         # Anamnesis vitae
      t.text :physical_examination    # Объективный осмотр
      t.text :study_protocol          # Протокол исследования
      t.jsonb :diagnoses, default: {} # Диагнозы (код МКБ, основное заболевание, вид диагноза)
      t.text :referrals               # Направления
      t.text :prescriptions           # Назначения
      t.text :recommendations         # Рекомендации врача
      t.text :notes                   # Примечания

      t.timestamps
    end
  end
end
