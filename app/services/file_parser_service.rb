# frozen_string_literal: true

# Сервис для парсинга файлов различных форматов
class FileParserService
  SUPPORTED_EXTENSIONS = %w[.pdf .docx .doc .xlsx .xls .txt].freeze

  class << self
    def parse(file_path)
      extension = File.extname(file_path).downcase
      
      unless SUPPORTED_EXTENSIONS.include?(extension)
        raise ArgumentError, "Неподдерживаемый формат файла: #{extension}"
      end

      case extension
      when ".pdf"
        parse_pdf(file_path)
      when ".docx", ".doc"
        parse_docx(file_path)
      when ".xlsx", ".xls"
        parse_excel(file_path)
      when ".txt"
        parse_txt(file_path)
      end
    end

    def parse_uploaded_file(uploaded_file)
      # Создаем временный файл для обработки
      temp_file = Tempfile.new([File.basename(uploaded_file.original_filename, ".*"), 
                                File.extname(uploaded_file.original_filename)])
      begin
        temp_file.binmode
        temp_file.write(uploaded_file.read)
        temp_file.rewind
        parse(temp_file.path)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    private

    def parse_pdf(file_path)
      reader = PDF::Reader.new(file_path)
      reader.pages.map(&:text).join("\n")
    rescue StandardError => e
      Rails.logger.error("PDF parsing error: #{e.message}")
      ""
    end

    def parse_docx(file_path)
      doc = Docx::Document.open(file_path)
      doc.paragraphs.map(&:text).join("\n")
    rescue StandardError => e
      Rails.logger.error("DOCX parsing error: #{e.message}")
      ""
    end

    def parse_excel(file_path)
      spreadsheet = Roo::Spreadsheet.open(file_path)
      text_parts = []

      spreadsheet.sheets.each do |sheet_name|
        sheet = spreadsheet.sheet(sheet_name)
        sheet.each_row_streaming do |row|
          text_parts << row.map { |cell| cell&.value.to_s }.join(" ")
        end
      end

      text_parts.join("\n")
    rescue StandardError => e
      Rails.logger.error("Excel parsing error: #{e.message}")
      ""
    end

    def parse_txt(file_path)
      File.read(file_path, encoding: "UTF-8")
    rescue StandardError => e
      Rails.logger.error("TXT parsing error: #{e.message}")
      ""
    end
  end
end
