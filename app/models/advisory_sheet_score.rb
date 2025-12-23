# frozen_string_literal: true

# Модель для хранения оценок заполненности ключевых полей консультативного листа
# Следует принципу Single Responsibility - только хранение данных и простые вычисления
#
# Бизнес-логика оценки вынесена в:
# - FieldEvaluator - оценка отдельных полей
# - AdvisorySheetScoringService - оркестрация процесса оценки
class AdvisorySheetScore < ApplicationRecord
  belongs_to :verified_advisory_sheet

  # Максимально возможный балл (10 полей × 1.0 балл)
  MAX_SCORE = 10.0

  # Названия полей для оценки
  SCOREABLE_FIELDS = %w[
    complaints
    anamnesis_morbi
    anamnesis_vitae
    physical_examination
    study_protocol
    diagnoses
    referrals
    prescriptions
    recommendations
    notes
  ].freeze

  # Валидация диапазона баллов (0, 0.5, или 1.0)
  validates :complaints_score, :anamnesis_morbi_score, :anamnesis_vitae_score,
            :physical_examination_score, :study_protocol_score, :diagnoses_score,
            :referrals_score, :prescriptions_score, :recommendations_score, :notes_score,
            inclusion: { in: [ 0.0, 0.5, 1.0 ] }

  validates :total_score, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: MAX_SCORE }
  validates :percentage, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }

  # Автоматический расчет итоговых баллов перед сохранением
  before_save :calculate_totals

  # Возвращает цвет для визуализации процента
  def percentage_color
    case percentage
    when 0...30 then "#DC2626"      # Темно-красный (tailwind red-600)
    when 30...60 then "#D97706"     # Темно-оранжевый/янтарный (tailwind amber-600)
    when 60...80 then "#2563EB"     # Темно-синий (tailwind blue-600)
    else "#16A34A"                   # Темно-зеленый (tailwind green-600)
    end
  end

  # Возвращает текстовую оценку качества
  def quality_label
    case percentage
    when 0...30 then "Критично низкое качество"
    when 30...60 then "Требует улучшения"
    when 60...80 then "Удовлетворительное качество"
    when 80...90 then "Хорошее качество"
    else "Отличное качество"
    end
  end

  private

  # Вычисляет итоговый балл и процент
  # Это простая математика, допустимая в модели
  def calculate_totals
    # Суммируем все баллы
    self.total_score = [
      complaints_score,
      anamnesis_morbi_score,
      anamnesis_vitae_score,
      physical_examination_score,
      study_protocol_score,
      diagnoses_score,
      referrals_score,
      prescriptions_score,
      recommendations_score,
      notes_score
    ].sum

    # Вычисляем процент от максимума
    self.percentage = (total_score / MAX_SCORE * 100).round(2)
  end
end
