# frozen_string_literal: true

namespace :advisory_sheets do
  desc "Обработка консультативных листов"

  # rake advisory_sheets:extract_fields
  # Извлекает поля для всех листов, у которых нет полей
  task extract_fields: :environment do
    puts "=" * 80
    puts "ИЗВЛЕЧЕНИЕ КЛЮЧЕВЫХ ПОЛЕЙ ИЗ КОНСУЛЬТАТИВНЫХ ЛИСТОВ"
    puts "=" * 80
    puts

    sheets_without_fields = VerifiedAdvisorySheet
                            .left_joins(:advisory_sheet_field)
                            .where(advisory_sheet_fields: { id: nil })

    total = sheets_without_fields.count
    puts "Найдено листов без извлеченных полей: #{total}"
    puts

    return if total.zero?

    progress = 0
    errors = 0

    sheets_without_fields.find_each do |sheet|
      progress += 1

      begin
        fields_data = AdvisorySheetFieldExtractionService.extract(sheet.body)
        sheet.create_advisory_sheet_field!(fields_data)
        print "\rОбработано: #{progress}/#{total}"
      rescue StandardError => e
        errors += 1
        puts "\nОшибка при обработке листа ##{sheet.recording}: #{e.message}"
      end
    end

    puts "\n"
    puts "=" * 80
    puts "Успешно обработано: #{progress - errors}"
    puts "Ошибок: #{errors}"
    puts "=" * 80
  end

  # rake advisory_sheets:calculate_scores
  # Рассчитывает оценки для всех листов, у которых есть поля но нет оценок
  task calculate_scores: :environment do
    puts "=" * 80
    puts "РАСЧЕТ ОЦЕНОК КАЧЕСТВА ЗАПОЛНЕНИЯ"
    puts "=" * 80
    puts

    sheets_without_scores = VerifiedAdvisorySheet
                            .joins(:advisory_sheet_field)
                            .left_joins(:advisory_sheet_score)
                            .where(advisory_sheet_scores: { id: nil })

    total = sheets_without_scores.count
    puts "Найдено листов без оценок: #{total}"
    puts

    return if total.zero?

    results = AdvisorySheetScoringService.score_all(sheets_without_scores)

    puts "=" * 80
    puts "Успешно оценено: #{results[:success]}"
    puts "Ошибок: #{results[:failed]}"
    puts "=" * 80
  end

  # rake advisory_sheets:recalculate_scores
  # Пересчитывает все существующие оценки
  task recalculate_scores: :environment do
    puts "=" * 80
    puts "ПЕРЕСЧЕТ ВСЕХ ОЦЕНОК КАЧЕСТВА"
    puts "=" * 80
    puts

    total = AdvisorySheetScore.count
    puts "Всего оценок для пересчета: #{total}"
    puts

    return if total.zero?

    results = AdvisorySheetScoringService.recalculate_all_scores

    puts "=" * 80
    puts "Успешно пересчитано: #{results[:recalculated]}"
    puts "Ошибок: #{results[:errors]}"
    puts "=" * 80
  end

  # rake advisory_sheets:full_process
  # Полная обработка: извлечение полей + расчет оценок
  task full_process: :environment do
    puts "=" * 80
    puts "ПОЛНАЯ ОБРАБОТКА КОНСУЛЬТАТИВНЫХ ЛИСТОВ"
    puts "=" * 80
    puts

    # Шаг 1: Извлечение полей
    Rake::Task["advisory_sheets:extract_fields"].invoke

    puts
    puts "Пауза 2 секунды..."
    sleep 2
    puts

    # Шаг 2: Расчет оценок
    Rake::Task["advisory_sheets:calculate_scores"].invoke

    puts
    puts "=" * 80
    puts "ПОЛНАЯ ОБРАБОТКА ЗАВЕРШЕНА"
    puts "=" * 80
  end

  # rake advisory_sheets:stats
  # Выводит статистику по листам и оценкам
  task stats: :environment do
    puts "=" * 80
    puts "СТАТИСТИКА ПО КОНСУЛЬТАТИВНЫМ ЛИСТАМ"
    puts "=" * 80
    puts

    total_sheets = VerifiedAdvisorySheet.count
    with_fields = VerifiedAdvisorySheet.joins(:advisory_sheet_field).count
    with_scores = VerifiedAdvisorySheet.joins(:advisory_sheet_score).count

    puts "Всего листов: #{total_sheets}"
    puts "С извлеченными полями: #{with_fields} (#{percentage(with_fields, total_sheets)}%)"
    puts "С оценками качества: #{with_scores} (#{percentage(with_scores, total_sheets)}%)"
    puts

    if with_scores.positive?
      summary = AdvisorySheetScoringService.quality_statistics

      puts "СТАТИСТИКА ПО КАЧЕСТВУ:"
      puts "-" * 80
      puts "Средний балл: #{summary[:average_total_score]} из 9.0"
      puts "Средний процент: #{summary[:average_percentage]}%"
      puts

      puts "РАСПРЕДЕЛЕНИЕ ПО КАЧЕСТВУ:"
      puts "  Отличное (90-100%):        #{summary[:by_quality][:excellent]}"
      puts "  Хорошее (80-89%):          #{summary[:by_quality][:good]}"
      puts "  Удовлетворительное (60-79%): #{summary[:by_quality][:satisfactory]}"
      puts "  Требует улучшения (30-59%): #{summary[:by_quality][:needs_improvement]}"
      puts "  Критично низкое (<30%):    #{summary[:by_quality][:critical]}"
      puts

      puts "СРЕДНИЕ БАЛЛЫ ПО ПОЛЯМ:"
      summary[:field_averages].each do |field, avg|
        puts "  #{field_label(field)}: #{avg} / 1.0"
      end
    end

    puts "=" * 80
  end

  # Вспомогательные методы
  def percentage(part, total)
    return 0 if total.zero?

    ((part.to_f / total) * 100).round(2)
  end

  def field_label(field)
    {
      complaints: "Жалобы",
      anamnesis_morbi: "Anamnesis morbi",
      anamnesis_vitae: "Anamnesis vitae",
      physical_examination: "Объективный осмотр",
      study_protocol: "Протокол исследования",
      diagnoses: "Диагнозы",
      referrals: "Направления",
      prescriptions: "Назначения",
      recommendations: "Рекомендации"
    }[field] || field.to_s
  end
end
