class VerifiedAdvisorySheet < ApplicationRecord
  ThinkingSphinx::Callbacks.append(self, behaviours: [ :real_time ])

  max_pages 100

  belongs_to :auditor, optional: true
  has_one :advisory_sheet_field, dependent: :destroy
  has_one :advisory_sheet_score, dependent: :destroy

  has_many :relationships_doctor_and_verified_advisory_sheets, foreign_key: :verified_advisory_sheet_id, class_name: "RelationshipDoctorAndVerifiedAdvisorySheet"
  has_many :doctors, through: :relationships_doctor_and_verified_advisory_sheets

  has_many :relationships_main_doctor_and_verified_advisory_sheets, foreign_key: :verified_advisory_sheet_id, class_name: "RelationshipMainDoctorAndVerifiedAdvisorySheet"
  has_many :main_doctors, through: :relationships_main_doctor_and_verified_advisory_sheets

  # Поддержка вложенных атрибутов для редактирования полей
  accepts_nested_attributes_for :advisory_sheet_field, allow_destroy: false
  accepts_nested_attributes_for :advisory_sheet_score, allow_destroy: false

  enum :status, { red: 0, yellow: 1, green: 2, purple: 3 }

  validates :recording, presence: true, uniqueness: true
  validates :body, presence: true
  validates :status, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :by_recording, ->(recording) { where("recording ILIKE ?", "%#{recording}%") }
  scope :by_body, ->(body) { where("body ILIKE ?", "%#{body}%") }

  # Полнотекстовый поиск через Sphinx
  # Ищет по всем полям: recording, body, original_filename
  def self.search_text(query)
    return all if query.blank?

    # Используем Sphinx для быстрого полнотекстового поиска
    # Получаем ID из Sphinx, затем загружаем через ActiveRecord
    sphinx_results = search(query)
    ids = sphinx_results.map(&:id)

    # Возвращаем ActiveRecord::Relation для совместимости с цепочками
    # Сохраняем порядок сортировки по дате создания
    ids.any? ? where(id: ids).order(created_at: :desc) : none
  end

  def status_color
    case status
    when "purple" then "#8200DB"
    when "red" then "#EF4444"
    when "yellow" then "#F59E0B"
    when "green" then "#10B981"
    end
  end

  def status_label
    case status
    when "purple" then "Не удалось проверить"
    when "red" then "Не соответствует"
    when "yellow" then "Частичное соответствие"
    when "green" then "Соответствует"
    end
  end
end
