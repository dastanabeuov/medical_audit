# frozen_string_literal: true

# Сервис для работы с Gemini AI
# Обеспечивает генерацию эмбеддингов и проверку КЛ
class GeminiService
  EMBEDDING_MODEL = "text-embedding-004"
  CHAT_MODEL = "gemini-2.0-flash-001"
  EMBEDDING_DIMENSION = 768

  class << self
    # Генерация эмбеддинга для текста
    def generate_embedding(text)
      return Array.new(EMBEDDING_DIMENSION, 0.0) if text.blank?

      response = RubyLLM.embed(
        text.truncate(8000),
        model: EMBEDDING_MODEL
      )

      # RubyLLM.embed возвращает объект RubyLLM::Embedding с методом .vectors
      response.vectors
    rescue StandardError => e
      Rails.logger.error("GeminiService embedding error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      Array.new(EMBEDDING_DIMENSION, 0.0)
    end

    # Проверка КЛ на соответствие протоколам и МКБ
    def verify_advisory_sheet(sanitized_content, relevant_protocols, relevant_mkbs)
      prompt = build_verification_prompt(sanitized_content, relevant_protocols, relevant_mkbs)

      chat = RubyLLM.chat(model: CHAT_MODEL)
      response = chat.ask(prompt)

      parse_verification_response(response)
    rescue StandardError => e
      Rails.logger.error("GeminiService verification error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      { status: :yellow, result: "Ошибка проверки: #{e.message}", recommendations: "" }
    end

    private

    def build_verification_prompt(content, protocols, mkbs)
      protocol_context = protocols.map { |p| "#{p.title}:\n#{p.content.truncate(2000)}" }.join("\n\n---\n\n")
      mkb_context = mkbs.map { |m| "#{m.code}: #{m.title}\n#{m.description}" }.join("\n")

      <<~PROMPT
        Ты медицинский аудитор. Проверь консультативный лист на соответствие протоколам МЗ РК и МКБ.

        ПРОТОКОЛЫ МЗ РК:
        #{protocol_context}

        КОДЫ МКБ:
        #{mkb_context}

        КОНСУЛЬТАТИВНЫЙ ЛИСТ (без персональных данных):
        #{content}

        Проанализируй и ответь СТРОГО в формате JSON:
        {
          "status": "red" или "yellow" или "green",
          "result": "подробное описание результата проверки",
          "recommendations": "рекомендации по исправлению (если есть)"
        }

        Критерии оценки:
        - "green" - полное соответствие протоколам и МКБ
        - "yellow" - частичное соответствие, есть незначительные отклонения
        - "red" - существенные нарушения протоколов или неверные коды МКБ

        Ответь ТОЛЬКО JSON без дополнительного текста.
      PROMPT
    end

    def parse_verification_response(response)
      # Извлекаем текстовое содержимое из RubyLLM::Message
      content = response.respond_to?(:content) ? response.content : response.to_s

      # Извлекаем JSON из ответа
      json_match = content.match(/\{[\s\S]*\}/)
      return default_response unless json_match

      parsed = JSON.parse(json_match[0])
      {
        status: parsed["status"]&.to_sym || :yellow,
        result: parsed["result"] || "Результат проверки недоступен",
        recommendations: parsed["recommendations"] || ""
      }
    rescue JSON::ParserError => e
      Rails.logger.error("GeminiService JSON parse error: #{e.message}")
      default_response
    end

    def default_response
      { status: :yellow, result: "Не удалось провести автоматическую проверку", recommendations: "" }
    end
  end
end
