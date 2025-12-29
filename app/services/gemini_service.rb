# frozen_string_literal: true

# Сервис для работы с Gemini AI
# Обеспечивает генерацию эмбеддингов и проверку КЛ
class GeminiService
  EMBEDDING_MODEL = "text-embedding-004"
  CHAT_MODEL = "gemini-2.0-flash-001"
  EMBEDDING_DIMENSION = 768
  # CHAT_MODEL = "gemini-2.5-flash"
  # THINKING_LEVEL = low # (low/high/medium)
  # THEMPORARY = 0.1

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
    # Возвращает общую оценку + детальный анализ по каждому полю
    def verify_advisory_sheet(sanitized_content, relevant_protocols, relevant_mkbs, extracted_fields = nil)
      prompt = build_verification_prompt(sanitized_content, relevant_protocols, relevant_mkbs, extracted_fields)

      chat = RubyLLM.chat(model: CHAT_MODEL)
      response = chat.ask(prompt)

      parse_verification_response(response)
    rescue StandardError => e
      Rails.logger.error("GeminiService verification error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      { status: :purple, result: "Ошибка проверки: #{e.message}", recommendations: "", field_analysis: {} }
    end

    private

    def build_verification_prompt(content, protocols, mkbs, extracted_fields = nil)
      protocol_context = protocols.map { |p| "#{p.title}:\n#{p.content.truncate(2000)}" }.join("\n\n---\n\n")
      mkb_context = mkbs.map { |m| "#{m.code}: #{m.title}\n#{m.description}" }.join("\n")

      fields_section = if extracted_fields.present?
        build_fields_section(extracted_fields)
      else
        ""
      end

      <<~PROMPT
        Ты медицинский аудитор. Проверь консультативный лист на соответствие протоколам МЗ РК и МКБ.

        ПРОТОКОЛЫ МЗ РК:
        #{protocol_context}

        КОДЫ МКБ:
        #{mkb_context}

        КОНСУЛЬТАТИВНЫЙ ЛИСТ (без персональных данных):
        #{content}

        #{fields_section}

        Проанализируй и ответь СТРОГО в формате JSON:
        {
          "status": "red" или "yellow" или "green",
          "result": "подробное описание результата проверки",
          "recommendations": "рекомендации по исправлению (если есть)",
          "field_analysis": {
            "complaints": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "anamnesis_morbi": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "anamnesis_vitae": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "physical_examination": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "study_protocol": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "diagnoses": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "referrals": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "prescriptions": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "recommendations": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"},
            "notes": {"score": 0.0 или 0.5 или 1.0, "comment": "Комментарии"}
          }
        }

        Критерии общей оценки (status):
        - "green" - полное соответствие протоколам и МКБ
        - "yellow" - частичное соответствие, есть незначительные отклонения
        - "red" - существенные нарушения протоколов или неверные коды МКБ

        Критерии оценки полей (field_analysis):
        - 1.0 балл: поле заполнено полностью и содержит всю необходимую медицинскую информацию.
        -- Проверка точности: провести антологический, семантический и смысловой анализ в соответствии с Протоколами МЗ РК и МКБ, чтобы определить:
        --- все ли элементы присутствуют,
        --- корректно ли они оформлены,
        --- соответствуют ли медицинским стандартам.

        - 0.5 балла: поле заполнено частично: присутствует значимая информация, но отсутствуют важные детали.
        -- Проверка точности: 
        --- провести антологический, 
        --- семантический и смысловой анализ по Протоколам МЗ РК и МКБ с целью выявления отсутствующих или некорректно указанных элементов.

        - 0.0 баллов: поле не заполнено, заполнено критически плохо либо содержит бессмысленную или нерелевантную информацию.
        -- Проверка точности:
        --- выполнить антологический,
        --- семантический и смысловой анализ по Протоколам МЗ РК и МКБ, чтобы выявить отсутствующие, искажённые или неправильно интерпретированные элементы.

        Комментарии (comment) должны быть:
        - Конкретными - Проверить точность: оценить антологические, семантические и смысловые значения по Протоколам МЗ РК и МКБ, выявив отсутствующие, некорректные или правильно заполненные элементы.
        - Краткими (1-3 предложения)
        - Профессиональными

        Ответь ТОЛЬКО JSON без дополнительного текста.
      PROMPT
    end

    # Формирует секцию с извлеченными полями для промпта
    def build_fields_section(fields)
      return "" if fields.blank?

      sections = []
      sections << "\nИЗВЛЕЧЕННЫЕ КЛЮЧЕВЫЕ ПОЛЯ (оцени каждое):"

      fields_map = {
        complaints: "Жалобы",
        anamnesis_morbi: "Anamnesis morbi",
        anamnesis_vitae: "Anamnesis vitae",
        physical_examination: "Объективный осмотр",
        study_protocol: "Протокол исследования",
        diagnoses: "Диагнозы",
        referrals: "Направления",
        prescriptions: "Назначения",
        recommendations: "Рекомендации врача",
        notes: "Примечания"
      }

      fields_map.each do |key, label|
        value = fields[key]
        next if value.blank?

        content = if key == :diagnoses && value.is_a?(Hash)
          format_diagnoses_for_prompt(value)
        else
          value.to_s.truncate(500)
        end

        sections << "\n#{label}:\n#{content}" if content.present?
      end

      sections.join("\n")
    end

    def format_diagnoses_for_prompt(diagnoses_hash)
      return "" if diagnoses_hash.blank? || diagnoses_hash.empty?

      parts = []
      parts << "Код МКБ: #{diagnoses_hash['mkb_code']}" if diagnoses_hash["mkb_code"].present?
      parts << "Заболевание: #{diagnoses_hash['main_disease']}" if diagnoses_hash["main_disease"].present?
      parts << "Вид диагноза: #{diagnoses_hash['diagnosis_type']}" if diagnoses_hash["diagnosis_type"].present?

      parts.join("\n")
    end

    def parse_verification_response(response)
      # Извлекаем текстовое содержимое из RubyLLM::Message
      content = response.respond_to?(:content) ? response.content : response.to_s

      # Извлекаем JSON из ответа
      json_match = content.match(/\{[\s\S]*\}/)
      return default_response unless json_match

      parsed = JSON.parse(json_match[0])

      # Парсим детальный анализ полей
      field_analysis = parse_field_analysis(parsed["field_analysis"])

      {
        status: parsed["status"]&.to_sym || :purple,
        result: parsed["result"] || "Результат проверки недоступен",
        recommendations: parsed["recommendations"] || "",
        field_analysis: field_analysis
      }
    rescue JSON::ParserError => e
      Rails.logger.error("GeminiService JSON parse error: #{e.message}")
      default_response
    end

    # Парсит и нормализует анализ полей из ответа AI
    def parse_field_analysis(raw_analysis)
      return {} if raw_analysis.blank?

      result = {}

      raw_analysis.each do |field_name, field_data|
        next unless field_data.is_a?(Hash)

        score = normalize_score(field_data["score"].to_f)
        comment = field_data["comment"]&.strip || ""

        result[field_name] = { score: score, comment: comment }
      end

      result
    end

    # Нормализует score к допустимым значениям (0.0, 0.5, 1.0)
    def normalize_score(score)
      case score
      when 0.0..0.25 then 0.0
      when 0.25..0.75 then 0.5
      when 0.75..1.0 then 1.0
      else 0.0
      end
    end

    def default_response
      { status: :purple, result: "Не удалось провести автоматическую проверку", recommendations: "", field_analysis: {} }
    end
  end
end
