# frozen_string_literal: true

# Сервис для загрузки и парсинга консультативных листов
class AdvisorySheetUploadService
  SUPPORTED_EXTENSIONS = %w[.pdf .docx .doc .xlsx .xls].freeze

  class << self
    # Обработка массовой загрузки файлов
    def process_files(files, auditor)
      results = { success: 0, failed: 0, errors: [] }

      Array(files).each do |file|
        # Пропускаем пустые строки (Rails иногда добавляет пустую строку в массив)
        next if file.blank? || file.is_a?(String)

        # Проверяем, что это действительно файл
        unless file.respond_to?(:original_filename)
          results[:failed] += 1
          results[:errors] << "Некорректный формат файла"
          next
        end

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

    def process_single_file(file, auditor)
      filename = file.original_filename
      extension = File.extname(filename).downcase

      unless SUPPORTED_EXTENSIONS.include?(extension)
        return { success: false, error: "Неподдерживаемый формат файла" }
      end

      content = FileParserService.parse_uploaded_file(file)

      return { success: false, error: "Не удалось прочитать файл" } if content.blank?

      recording = extract_recording(content)

      return { success: false, error: "Не найден номер записи по приему" } if recording.blank?

      sheet = NotVerifiedAdvisorySheet.new(
        recording: recording,
        body: content,
        auditor: auditor,
        original_filename: filename
      )

      if sheet.save
        { success: true, sheet: sheet }
      else
        { success: false, error: sheet.errors.full_messages.join(", ") }
      end
    rescue StandardError => e
      Rails.logger.error("AdvisorySheetUploadService error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      { success: false, error: e.message }
    end

    private

    def extract_recording(content)
      match = content.match(/Записи\s+по\s+приему\s*#?\s*(\d+)/i)
      match ? match[1] : nil
    end
  end
end
