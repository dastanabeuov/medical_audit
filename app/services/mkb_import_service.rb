# frozen_string_literal: true

# Сервис для импорта кодов МКБ из папки data_mkb
class MkbImportService
  DATA_PATH = Rails.root.join("data_mkb")

  class << self
    # Импорт всех МКБ из папки
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

      Rails.logger.info("MkbImportService: импортировано #{imported} кодов МКБ")
      { success: true, imported: imported, errors: errors }
    end

    # Импорт одного файла
    def import_file(file_path)
      content = FileParserService.parse(file_path)
      return { success: false, error: "Не удалось прочитать файл" } if content.blank?

      mkb_entries = parse_mkb_entries(content, file_path)
      count = 0

      mkb_entries.each do |mkb_data|
        mkb = Mkb.find_or_initialize_by(code: mkb_data[:code])
        
        mkb.title = mkb_data[:title]
        mkb.description = mkb_data[:description]
        mkb.source_file = File.basename(file_path)
        
        # Генерируем эмбеддинг
        mkb.embedding = GeminiService.generate_embedding(mkb.full_text)
        
        if mkb.save
          count += 1
        else
          Rails.logger.error("MKB save error: #{mkb.errors.full_messages}")
        end
      end

      { success: true, count: count }
    rescue StandardError => e
      Rails.logger.error("MkbImportService error: #{e.message}")
      { success: false, error: e.message }
    end

    # Обновление базы - удаляет старые и импортирует заново
    def refresh_all
      Mkb.delete_all
      import_all
    end

    private

    # Парсинг МКБ кодов из текста
    def parse_mkb_entries(content, _file_path)
      entries = []
      
      # МКБ коды имеют формат: A00-B99, A00.0, M54.5 и т.д.
      # Ищем строки с кодами МКБ
      lines = content.split("\n")
      
      lines.each do |line|
        # Паттерн для кодов МКБ-10
        match = line.match(/^([A-Z]\d{2}(?:\.\d{1,2})?(?:-[A-Z]?\d{2}(?:\.\d)?)?)\s*[:\-–]?\s*(.+)/i)
        
        if match
          code = match[1].upcase
          title = match[2].strip
          
          entries << {
            code: code,
            title: title.truncate(500),
            description: extract_description(content, code)
          }
        end
      end

      # Если не нашли структурированные коды, пробуем другой подход
      if entries.empty?
        entries = parse_unstructured_mkb(content)
      end

      entries
    end

    # Извлечение описания для кода МКБ
    def extract_description(content, code)
      # Ищем блок текста после кода
      pattern = /#{Regexp.escape(code)}[:\-–]?\s*[^\n]+\n((?:(?![A-Z]\d{2})[^\n]*\n?)*)/i
      match = content.match(pattern)
      match ? match[1].strip.truncate(2000) : nil
    end

    # Парсинг неструктурированного МКБ текста
    def parse_unstructured_mkb(content)
      entries = []
      
      # Ищем все упоминания кодов МКБ в тексте
      content.scan(/([A-Z]\d{2}(?:\.\d{1,2})?)\s*[:\-–]?\s*([^.!\n]{10,})/i) do |code, title|
        entries << {
          code: code.upcase,
          title: title.strip.truncate(500),
          description: nil
        }
      end

      entries.uniq { |e| e[:code] }
    end
  end
end
