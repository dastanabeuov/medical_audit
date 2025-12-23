# frozen_string_literal: true

# Модель для хранения структурированных ключевых полей консультативного листа
# Используется для детального анализа и оценки заполнения медицинской документации
class AdvisorySheetField < ApplicationRecord
  belongs_to :verified_advisory_sheet

  # Валидация наличия хотя бы одного заполненного поля
  validate :at_least_one_field_present

  # Проверяет, заполнено ли поле (не пустое и не содержит только "не указано", "н/д", и т.п.)
  def field_filled?(field_value)
    return false if field_value.blank?

    # Список маркеров пустого/отсутствующего значения
    empty_markers = [
      "не указано", "не заполнено", "нет данных", "н/д", "отсутствует",
      "—", "-", ".", "…", "……", "………"
    ]

    normalized = field_value.to_s.strip.downcase
    !empty_markers.include?(normalized)
  end

  # Возвращает список заполненных полей
  def filled_fields
    fields = {}
    %i[complaints anamnesis_morbi anamnesis_vitae physical_examination
       study_protocol referrals prescriptions recommendations notes].each do |field|
      fields[field] = send(field) if field_filled?(send(field))
    end

    # Для диагнозов проверяем отдельно
    fields[:diagnoses] = diagnoses if diagnoses.present? && diagnoses.any?

    fields
  end

  # Возвращает количество заполненных полей из всех возможных (10 полей)
  def filled_fields_count
    filled_fields.count
  end

  # Процент заполненности (от 0 до 100)
  def completeness_percentage
    total_fields = 10
    (filled_fields_count.to_f / total_fields * 100).round(2)
  end

  private

  def at_least_one_field_present
    if [ complaints, anamnesis_morbi, anamnesis_vitae, physical_examination,
         study_protocol, referrals, prescriptions, recommendations, notes ].all?(&:blank?) &&
       (diagnoses.blank? || diagnoses.empty?)
      errors.add(:base, "Должно быть заполнено хотя бы одно ключевое поле")
    end
  end
end
