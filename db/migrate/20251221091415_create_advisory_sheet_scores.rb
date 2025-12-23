class CreateAdvisorySheetScores < ActiveRecord::Migration[8.0]
  def change
    create_table :advisory_sheet_scores do |t|
      t.references :verified_advisory_sheet, null: false, foreign_key: true, index: { unique: true }

      # Баллы для каждого ключевого поля (0, 0.5, или 1.0)
      t.decimal :complaints_score, precision: 3, scale: 1, default: 0.0
      t.decimal :anamnesis_morbi_score, precision: 3, scale: 1, default: 0.0
      t.decimal :anamnesis_vitae_score, precision: 3, scale: 1, default: 0.0
      t.decimal :physical_examination_score, precision: 3, scale: 1, default: 0.0
      t.decimal :study_protocol_score, precision: 3, scale: 1, default: 0.0
      t.decimal :diagnoses_score, precision: 3, scale: 1, default: 0.0
      t.decimal :referrals_score, precision: 3, scale: 1, default: 0.0
      t.decimal :prescriptions_score, precision: 3, scale: 1, default: 0.0
      t.decimal :recommendations_score, precision: 3, scale: 1, default: 0.0
      t.decimal :notes_score, precision: 3, scale: 1, default: 0.0

      # Итоговый балл (сумма всех баллов из 10.0)
      t.decimal :total_score, precision: 4, scale: 1, default: 0.0

      # Процент от максимума (0-100%)
      t.decimal :percentage, precision: 5, scale: 2, default: 0.0

      t.timestamps
    end
  end
end
