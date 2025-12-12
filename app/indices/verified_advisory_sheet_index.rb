ThinkingSphinx::Index.define :verified_advisory_sheet, with: :real_time do
  # fields
  indexes recording, sortable: true
  indexes body
  indexes status, sortable: true

  # attributes
  has auditor_id,  type: :integer
  has created_at, type: :timestamp
  has updated_at, type: :timestamp
end
