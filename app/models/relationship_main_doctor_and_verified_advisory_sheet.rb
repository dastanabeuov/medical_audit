# frozen_string_literal: true

# Связь между главными врачами и проверенными консультативными листами
class RelationshipMainDoctorAndVerifiedAdvisorySheet < ApplicationRecord
  self.table_name = "relationships_main_doctor_and_verified_advisory_sheets"

  belongs_to :main_doctor
  belongs_to :verified_advisory_sheet

  validates :main_doctor_id, presence: true
  validates :verified_advisory_sheet_id, presence: true
  validates :main_doctor_id, uniqueness: { scope: :verified_advisory_sheet_id }
end
