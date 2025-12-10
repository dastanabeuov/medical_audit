# frozen_string_literal: true

# Сервис для импорта протоколов МЗ РК из папки data_protocol
class ProtocolImportService
  DATA_PATH = Rails.root.join("data_protocol")

  class << self
    # Импорт всех протоколов из папки
    def import_all
      return { success: false, error: "Папка #{DATA_PATH} не существует" } unless Dir.exist?(DATA_PATH)

      files = Dir.glob(File.join(DATA_PATH, "**/*")).select { |f| File.file?(f) }
      
      imported = 0
      errors = []

      files.each do |file_path|
        result = import_file(file_path)
        if result[:success]
          imported += result[:count]
        else
          errors << "#{File.basename(file_path)}: #{result[:error]}"
        end
      end

      Rails.logger.info("ProtocolImportService: импортировано #{imported} протоколов")
      { success: true, imported: imported, errors: errors }
    end

    # Импорт одного файла
    def import_file(file_path)
      content = FileParserService.parse(file_path)
      return { success: false, error: "Не удалось прочитать файл" } if content.blank?

      protocols = parse_protocols(content, file_path)
      count = 0

      protocols.each do |protocol_data|
        protocol = Protocol.find_or_initialize_by(
          title: protocol_data[:title],
          source_file: File.basename(file_path)
        )
        
        protocol.content = protocol_data[:content]
        protocol.code = protocol_data[:code]
        
        # Генерируем эмбеддинг
        protocol.embedding = GeminiService.generate_embedding(protocol.full_text)
        
        if protocol.save
          count += 1
        else
          Rails.logger.error("Protocol save error: #{protocol.errors.full_messages}")
        end
      end

      { success: true, count: count }
    rescue StandardError => e
      Rails.logger.error("ProtocolImportService error: #{e.message}")
      { success: false, error: e.message }
    end

    # Обновление базы - удаляет старые и импортирует заново
    def refresh_all
      Protocol.delete_all
      import_all
    end

    private

    # Парсинг протоколов из текста
    # Предполагаем, что один файл может содержать несколько протоколов
    def parse_protocols(content, file_path)
      protocols = []
      
      # Пытаемся разделить по заголовкам протоколов
      # Обычно протоколы начинаются с "КЛИНИЧЕСКИЙ ПРОТОКОЛ" или похожего заголовка
      sections = content.split(/(?=(?:КЛИНИЧЕСКИЙ\s+)?ПРОТОКОЛ\s+(?:ДИАГНОСТИКИ|ЛЕЧЕНИЯ))/i)
      
      if sections.length > 1
        sections.each do |section|
          next if section.strip.blank?
          
          title = extract_protocol_title(section)
          code = extract_protocol_code(section)
          
          protocols << {
            title: title || "Протокол из #{File.basename(file_path)}",
            code: code,
            content: section.strip
          }
        end
      else
        # Один протокол на файл
        protocols << {
          title: extract_protocol_title(content) || File.basename(file_path, ".*"),
          code: extract_protocol_code(content),
          content: content.strip
        }
      end

      protocols
    end

    def extract_protocol_title(content)
      # Ищем заголовок протокола
      match = content.match(/(?:КЛИНИЧЕСКИЙ\s+)?ПРОТОКОЛ\s+(?:ДИАГНОСТИКИ\s+И\s+ЛЕЧЕНИЯ|ЛЕЧЕНИЯ|ДИАГНОСТИКИ)\s*[:\n]?\s*([^\n]+)/i)
      match ? match[1].strip.truncate(200) : nil
    end

    def extract_protocol_code(content)
      # Ищем код протокола (например, "№ 1" или "КП-123")
      match = content.match(/(?:№|номер|код)[\s:]*([А-Яа-яA-Za-z\d\-]+)/i)
      match ? match[1].strip : nil
    end
  end
end
