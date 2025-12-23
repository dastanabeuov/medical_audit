# frozen_string_literal: true

# Сервис для получения статистики по оценкам качества консультативных листов
# ПРИМЕЧАНИЕ: Оценка теперь происходит автоматически через AI в AdvisorySheetVerificationService
# Этот сервис содержит только статистические методы
class AdvisorySheetScoringService
  class << self

    # Получает статистику по качеству заполнения
    # @return [Hash] - статистика с группировкой по качеству
    def quality_statistics
      scores = AdvisorySheetScore.all

      {
        total: scores.count,
        average_score: scores.average(:total_score)&.round(2) || 0.0,
        average_percentage: scores.average(:percentage)&.round(2) || 0.0,
        by_quality: {
          excellent: scores.where("percentage >= ?", 90).count,     # 90-100%
          good: scores.where("percentage >= ? AND percentage < ?", 80, 90).count,  # 80-89%
          satisfactory: scores.where("percentage >= ? AND percentage < ?", 60, 80).count, # 60-79%
          needs_improvement: scores.where("percentage >= ? AND percentage < ?", 30, 60).count, # 30-59%
          critical: scores.where("percentage < ?", 30).count        # 0-29%
        }
      }
    end

    # Получает листы с низким качеством заполнения (< 60%)
    # @param limit [Integer] - количество записей
    # @return [ActiveRecord::Relation] - листы с низкими оценками
    def low_quality_sheets(limit: 50)
      VerifiedAdvisorySheet
        .joins(:advisory_sheet_score)
        .where("advisory_sheet_scores.percentage < ?", 60)
        .order("advisory_sheet_scores.percentage ASC")
        .limit(limit)
    end

    # Получает листы с высоким качеством заполнения (>= 80%)
    # @param limit [Integer] - количество записей
    # @return [ActiveRecord::Relation] - листы с высокими оценками
    def high_quality_sheets(limit: 50)
      VerifiedAdvisorySheet
        .joins(:advisory_sheet_score)
        .where("advisory_sheet_scores.percentage >= ?", 80)
        .order("advisory_sheet_scores.percentage DESC")
        .limit(limit)
    end
  end
end
