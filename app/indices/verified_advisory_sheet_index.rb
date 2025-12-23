ThinkingSphinx::Index.define :verified_advisory_sheet, with: :real_time do
  # fields (полнотекстовый поиск)
  indexes recording, sortable: true
  indexes body
  indexes original_filename  # добавляем поиск по имени файла/пациента

  # attributes (для фильтрации и сортировки)
  has auditor_id, type: :integer
  has status, type: :integer
  has created_at, type: :timestamp
  has updated_at, type: :timestamp
end
