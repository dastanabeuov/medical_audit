class Audit < ApplicationRecord
  belongs_to :consultation_sheet
  belongs_to :auditor
end
