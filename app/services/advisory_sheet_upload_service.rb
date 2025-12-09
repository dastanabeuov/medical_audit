# frozen_string_literal: true

# Сервис для загрузки и парсинга консультативных листов
class AdvisorySheetUploadService
  class << self
    # Обработка массовой загрузки файлов
    def process_files(files, auditor)
      results = { success: 0, failed: 0, errors: [] }

      files.each do |file|
        result = process_single_file(file, auditor)

        if result[:success]
          results[:success] += 1
        else
          results[:failed] += 1
          results[:errors] << "#{file.original_filename}: #{result[:error]}"
        end
      end

      results
    end

    # Обработка одного файла
    def process_single_file(file, auditor)
      # Парсим содержимое файла
      content = FileParserService.parse_uploaded_file(file)

      return { success: false, error: "Не удалось прочитать файл" } if content.blank?

      # Извлекаем номер записи
      recording = extract_recording(content)

      return { success: false, error: "Не найден номер записи по приему" } if recording.blank?

      # Создаем запись в not_verified_advisory_sheets
      sheet = NotVerifiedAdvisorySheet.new(
        recording: recording,
        body: content,
        auditor: auditor,
        original_filename: file.original_filename
      )

      if sheet.save
        { success: true, sheet: sheet }
      else
        { success: false, error: sheet.errors.full_messages.join(", ") }
      end
    rescue StandardError => e
      Rails.logger.error("AdvisorySheetUploadService error: #{e.message}")
      { success: false, error: e.message }
    end

    private

    def extract_recording(content)
      # Ищем номер записи по приему
      # Формат: "Записи по приему # 427009401763637180"
      match = content.match(/Записи\s+по\s+приему\s*#?\s*(\d+)/i)
      match ? match[1] : nil
    end
  end
end
