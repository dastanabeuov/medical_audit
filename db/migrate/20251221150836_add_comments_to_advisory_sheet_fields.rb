class AddCommentsToAdvisorySheetFields < ActiveRecord::Migration[8.0]
  def change
    add_column :advisory_sheet_fields, :complaints_comment, :text
    add_column :advisory_sheet_fields, :anamnesis_morbi_comment, :text
    add_column :advisory_sheet_fields, :anamnesis_vitae_comment, :text
    add_column :advisory_sheet_fields, :physical_examination_comment, :text
    add_column :advisory_sheet_fields, :study_protocol_comment, :text
    add_column :advisory_sheet_fields, :diagnoses_comment, :text
    add_column :advisory_sheet_fields, :referrals_comment, :text
    add_column :advisory_sheet_fields, :prescriptions_comment, :text
    add_column :advisory_sheet_fields, :recommendations_comment, :text
    add_column :advisory_sheet_fields, :notes_comment, :text
  end
end
