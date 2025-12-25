# frozen_string_literal: true

# Связь между врачами и проверенными консультативными листами
class RelationshipDoctorAndVerifiedAdvisorySheet < ApplicationRecord
  self.table_name = "relationships_doctor_and_verified_advisory_sheets"

  belongs_to :doctor
  belongs_to :verified_advisory_sheet

  validates :doctor_id, presence: true
  validates :verified_advisory_sheet_id, presence: true
  validates :doctor_id, uniqueness: { scope: :verified_advisory_sheet_id }
end
