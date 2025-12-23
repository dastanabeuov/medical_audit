# frozen_string_literal: true

# Сервис для генерации данных отчетов по консультативным листам
# Отвечает ТОЛЬКО за подготовку данных, не за форматирование
# Следует принципу Single Responsibility
class AdvisorySheetReportService
  # Структура данных для одной строки отчета
  ReportRow = Struct.new(
    :recording,                    # Номер записи
    :original_filename,            # Исходный файл
    :status,                       # Статус проверки
    :verified_at,                  # Дата проверки
    :complaints_score,             # Балл: Жалобы
    :anamnesis_morbi_score,        # Балл: Anamnesis morbi
    :anamnesis_vitae_score,        # Балл: Anamnesis vitae
    :physical_examination_score,   # Балл: Объективный осмотр
    :study_protocol_score,         # Балл: Протокол исследования
    :diagnoses_score,              # Балл: Диагнозы
    :referrals_score,              # Балл: Направления
    :prescriptions_score,          # Балл: Назначения
    :recommendations_score,        # Балл: Рекомендации
    :total_score,                  # Итоговый балл
    :percentage,                   # Процент качества
    :quality_label,                # Оценка качества
    keyword_init: true
  )

  class << self
    # Генерирует данные отчета для коллекции листов
    # @param sheets [ActiveRecord::Relation] - листы для отчета
    # @return [Array<ReportRow>] - массив строк отчета
    def generate_report_data(sheets = VerifiedAdvisorySheet.all)
      sheets
        .includes(:advisory_sheet_score)
        .order(verified_at: :desc)
        .map { |sheet| build_report_row(sheet) }
    end

    # Генерирует сводную статистику
    # @param sheets [ActiveRecord::Relation] - листы для анализа
    # @return [Hash] - статистика
    def generate_summary(sheets = VerifiedAdvisorySheet.all)
      scores = sheets.joins(:advisory_sheet_score).includes(:advisory_sheet_score)

      {
        total_sheets: sheets.count,
        with_scores: scores.count,
        average_total_score: calculate_average(scores, :total_score),
        average_percentage: calculate_average(scores, :percentage),
        by_status: group_by_status(sheets),
        by_quality: group_by_quality(scores),
        field_averages: calculate_field_averages(scores)
      }
    end

    # Генерирует заголовки для CSV/XLSX
    # @return [Array<String>] - массив заголовков
    def report_headers
      [
        "Номер записи",
        "Исходный файл",
        "Статус проверки",
        "Дата проверки",
        "Жалобы (балл)",
        "Anamnesis morbi (балл)",
        "Anamnesis vitae (балл)",
        "Объективный осмотр (балл)",
        "Протокол исследования (балл)",
        "Диагнозы (балл)",
        "Направления (балл)",
        "Назначения (балл)",
        "Рекомендации (балл)",
        "Итоговый балл",
        "Процент качества",
        "Оценка качества"
      ]
    end

    # Конвертирует ReportRow в массив значений для CSV/XLSX
    # @param row [ReportRow] - строка отчета
    # @return [Array] - массив значений
    def row_to_array(row)
      [
        row.recording,
        row.original_filename,
        row.status,
        row.verified_at&.strftime("%d.%m.%Y %H:%M"),
        row.complaints_score,
        row.anamnesis_morbi_score,
        row.anamnesis_vitae_score,
        row.physical_examination_score,
        row.study_protocol_score,
        row.diagnoses_score,
        row.referrals_score,
        row.prescriptions_score,
        row.recommendations_score,
        row.total_score,
        row.percentage,
        row.quality_label
      ]
    end

    private

    # Строит одну строку отчета из листа
    def build_report_row(sheet)
      score = sheet.advisory_sheet_score

      ReportRow.new(
        recording: sheet.recording,
        original_filename: sheet.original_filename || "—",
        status: sheet.status_label,
        verified_at: sheet.verified_at,
        complaints_score: score&.complaints_score || 0.0,
        anamnesis_morbi_score: score&.anamnesis_morbi_score || 0.0,
        anamnesis_vitae_score: score&.anamnesis_vitae_score || 0.0,
        physical_examination_score: score&.physical_examination_score || 0.0,
        study_protocol_score: score&.study_protocol_score || 0.0,
        diagnoses_score: score&.diagnoses_score || 0.0,
        referrals_score: score&.referrals_score || 0.0,
        prescriptions_score: score&.prescriptions_score || 0.0,
        recommendations_score: score&.recommendations_score || 0.0,
        total_score: score&.total_score || 0.0,
        percentage: score&.percentage || 0.0,
        quality_label: score&.quality_label || "Не оценено"
      )
    end

    # Вычисляет среднее значение для атрибута
    def calculate_average(relation, attribute)
      avg = relation.joins(:advisory_sheet_score)
                    .average("advisory_sheet_scores.#{attribute}")
      avg&.round(2) || 0.0
    end

    # Группирует по статусу проверки
    def group_by_status(sheets)
      sheets.group(:status).count.transform_keys do |key|
        VerifiedAdvisorySheet.new(status: key).status_label
      end
    end

    # Группирует по качеству
    def group_by_quality(scores)
      {
        excellent: scores.joins(:advisory_sheet_score)
                        .where("advisory_sheet_scores.percentage >= ?", 90).count,
        good: scores.joins(:advisory_sheet_score)
                   .where("advisory_sheet_scores.percentage >= ? AND advisory_sheet_scores.percentage < ?", 80, 90).count,
        satisfactory: scores.joins(:advisory_sheet_score)
                           .where("advisory_sheet_scores.percentage >= ? AND advisory_sheet_scores.percentage < ?", 60, 80).count,
        needs_improvement: scores.joins(:advisory_sheet_score)
                                .where("advisory_sheet_scores.percentage >= ? AND advisory_sheet_scores.percentage < ?", 30, 60).count,
        critical: scores.joins(:advisory_sheet_score)
                       .where("advisory_sheet_scores.percentage < ?", 30).count
      }
    end

    # Вычисляет средние баллы по каждому полю
    def calculate_field_averages(scores)
      {
        complaints: calculate_average(scores, :complaints_score),
        anamnesis_morbi: calculate_average(scores, :anamnesis_morbi_score),
        anamnesis_vitae: calculate_average(scores, :anamnesis_vitae_score),
        physical_examination: calculate_average(scores, :physical_examination_score),
        study_protocol: calculate_average(scores, :study_protocol_score),
        diagnoses: calculate_average(scores, :diagnoses_score),
        referrals: calculate_average(scores, :referrals_score),
        prescriptions: calculate_average(scores, :prescriptions_score),
        recommendations: calculate_average(scores, :recommendations_score)
      }
    end
  end
end
