# frozen_string_literal: true

# Сервис для проверки консультативных листов
# Использует RAG для поиска релевантных протоколов и МКБ
class AdvisorySheetVerificationService
  RELEVANT_PROTOCOLS_LIMIT = 5
  RELEVANT_MKB_LIMIT = 10

  class << self
    # Проверка одного КЛ
    def verify(not_verified_sheet)
      # 1. Санитизация персональных данных
      sanitized_content = PersonalDataSanitizerService.extract_medical_content(not_verified_sheet.body)

      return create_error_result(not_verified_sheet) if sanitized_content.blank?

      # 2. Генерация эмбеддинга для поиска
      query_embedding = GeminiService.generate_embedding(sanitized_content)

      # 3. Поиск релевантных протоколов и МКБ
      relevant_protocols = find_relevant_protocols(query_embedding, sanitized_content)
      relevant_mkbs = find_relevant_mkbs(query_embedding, sanitized_content)

      # 4. Проверка через AI
      verification = GeminiService.verify_advisory_sheet(
        sanitized_content,
        relevant_protocols,
        relevant_mkbs
      )

      # 5. Создание записи в verified_advisory_sheets
      create_verified_sheet(not_verified_sheet, verification)
    end

    # Массовая проверка всех непроверенных КЛ
    def verify_all_pending
      not_verified = NotVerifiedAdvisorySheet.all
      results = { success: 0, failed: 0 }

      not_verified.find_each do |sheet|
        result = verify(sheet)
        if result
          results[:success] += 1
          sheet.destroy
        else
          results[:failed] += 1
        end
      end

      results
    end

    private

    def find_relevant_protocols(query_embedding, text_content)
      # Сначала ищем по векторному сходству
      vector_results = Protocol.search_similar(query_embedding, limit: RELEVANT_PROTOCOLS_LIMIT)

      # Дополнительно ищем по ключевым словам из текста
      keywords = extract_medical_keywords(text_content)
      text_results = keywords.flat_map do |keyword|
        Protocol.search_by_text(keyword).limit(2)
      end

      (vector_results + text_results).uniq.first(RELEVANT_PROTOCOLS_LIMIT)
    end

    def find_relevant_mkbs(query_embedding, text_content)
      # Извлекаем МКБ коды из текста КЛ
      mkb_codes_in_text = extract_mkb_codes(text_content)

      # Ищем эти коды в базе
      direct_mkbs = Mkb.where(code: mkb_codes_in_text)

      # Дополняем векторным поиском
      vector_results = Mkb.search_similar(query_embedding, limit: RELEVANT_MKB_LIMIT - direct_mkbs.count)

      (direct_mkbs.to_a + vector_results).uniq.first(RELEVANT_MKB_LIMIT)
    end

    def extract_mkb_codes(text)
      # Извлекаем коды МКБ из текста (формат: A00.0, M54.5, и т.д.)
      text.scan(/[A-Z]\d{2}(?:\.\d{1,2})?/i).map(&:upcase).uniq
    end

    def extract_medical_keywords(text)
      # Извлекаем медицинские термины для текстового поиска
      # Фильтруем короткие слова и общеупотребимые
      stop_words = %w[при для или что как это был была были есть]

      text.scan(/[А-Яа-яЁё]{5,}/)
          .map(&:downcase)
          .uniq
          .reject { |w| stop_words.include?(w) }
          .first(10)
    end

    def create_verified_sheet(not_verified, verification)
      VerifiedAdvisorySheet.create!(
        recording: not_verified.recording,
        body: not_verified.body,
        status: verification[:status],
        verification_result: verification[:result],
        recommendations: verification[:recommendations],
        auditor_id: not_verified.auditor_id,
        original_filename: not_verified.original_filename,
        verified_at: Time.current
      )
    end

    def create_error_result(not_verified)
      VerifiedAdvisorySheet.create!(
        recording: not_verified.recording,
        body: not_verified.body,
        status: :yellow,
        verification_result: "Не удалось извлечь медицинскую информацию для проверки",
        recommendations: "Требуется ручная проверка",
        auditor_id: not_verified.auditor_id,
        original_filename: not_verified.original_filename,
        verified_at: Time.current
      )
    end
  end
end
