class AuditAnalyzerService
  SYSTEM_PROMPT = <<~PROMPT
    Ты - эксперт по медицинскому аудиту в Республике Казахстан.

    Твоя задача - проанализировать консультативный лист (КЛ) на соответствие:
    1. МКБ-10/11 (правильность кодирования диагноза)
    2. Протоколам Министерства Здравоохранения РК
    3. Клиническим рекомендациям

    ВАЖНО:
    - Используй ТОЛЬКО информацию из предоставленной базы знаний
    - Если информации недостаточно, укажи это
    - Будь объективным и конкретным
    - Указывай ссылки на источники

    ФОРМАТ ОТВЕТА (JSON):
    {
      "score": 0-100,
      "summary": "Краткое резюме",
      "violations": [
        {
          "category": "МКБ|Протокол|Оформление",
          "severity": "critical|major|minor",
          "description": "Описание нарушения",
          "reference": "Ссылка на источник",
          "recommendation": "Рекомендация"
        }
      ],
      "strengths": ["Что сделано правильно"],
      "requires_attention": true|false
    }
  PROMPT

  def initialize(consultation_sheet)
    @sheet = consultation_sheet
    @chat = RubyLLM.chat(provider: :anthropic, model: "claude-sonnet-4-20250514")
  end

  def analyze
    # 1. Извлекаем ключевую информацию из КЛ
    extracted_info = extract_key_information

    # 2. Получаем релевантный контекст из базы знаний
    context = retrieve_relevant_context(extracted_info)

    # 3. Выполняем анализ с помощью LLM
    analysis_result = perform_llm_analysis(context, extracted_info)

    # 4. Парсим и валидируем результат
    parse_and_validate_result(analysis_result)
  end

  private

  def extract_key_information
    prompt = <<~PROMPT
      Извлеки из консультативного листа:
      1. Диагноз (основной и сопутствующие)
      2. Код МКБ
      3. Проведенные обследования
      4. Назначенное лечение
      5. Рекомендации

      Консультативный лист:
      Пациент: #{@sheet.patient_name}
      Диагноз: #{@sheet.diagnosis}

      #{@sheet.content}

      Ответь в формате JSON:
      {
        "diagnosis": {"primary": "...", "secondary": ["..."]},
        "icd_code": "...",
        "examinations": ["..."],
        "treatment": ["..."],
        "recommendations": ["..."]
      }
    PROMPT

    response = @chat.ask(prompt)
    JSON.parse(response.content.gsub(/```json|```/, "").strip)
  rescue JSON::ParserError
    # Fallback на простое извлечение
    {
      diagnosis: { primary: @sheet.diagnosis, secondary: [] },
      icd_code: extract_icd_code(@sheet.content),
      examinations: [],
      treatment: [],
      recommendations: []
    }
  end

  def retrieve_relevant_context(extracted_info)
    # Формируем поисковые запросы
    queries = [
      extracted_info["diagnosis"]["primary"],
      extracted_info["icd_code"],
      extracted_info["treatment"].join(" ")
    ].compact

    # Получаем контекст для каждого запроса
    contexts = queries.flat_map do |query|
      RagRetrieverService.new(query).retrieve(limit: 3)
    end.uniq(&:id)

    # Формируем единый контекст
    contexts.map do |doc|
      <<~TEXT
        [#{doc.document_type.upcase}] #{doc.title}
        Источник: #{doc.source}

        #{doc.content.truncate(1500)}
      TEXT
    end.join("\n\n" + ("=" * 80) + "\n\n")
  end

  def perform_llm_analysis(context, extracted_info)
    prompt = <<~PROMPT
      БАЗА ЗНАНИЙ:
      #{context}

      #{("=" * 80)}

      КОНСУЛЬТАТИВНЫЙ ЛИСТ ДЛЯ АНАЛИЗА:
      Пациент: #{@sheet.patient_name}
      ID: #{@sheet.patient_id}
      Диагноз: #{@sheet.diagnosis}

      Извлеченная информация:
      #{JSON.pretty_generate(extracted_info)}

      Полный текст КЛ:
      #{@sheet.content}

      #{("=" * 80)}

      Проанализируй КЛ на соответствие базе знаний.
      Ответ СТРОГО в формате JSON (без markdown).
    PROMPT

    response = @chat
      .with_instructions(SYSTEM_PROMPT)
      .with_temperature(0.1) # Низкая температура для объективности
      .ask(prompt)

    response.content
  end

  def parse_and_validate_result(llm_response)
    # Очищаем от markdown
    cleaned = llm_response.gsub(/```json|```/, "").strip

    result = JSON.parse(cleaned)

    # Валидация обязательных полей
    unless result["score"] && result["summary"] && result["violations"]
      raise "Invalid analysis result format"
    end

    # Нормализация score
    result["score"] = result["score"].to_f.clamp(0, 100)

    {
      score: result["score"],
      summary: result["summary"],
      findings: {
        violations: result["violations"] || [],
        strengths: result["strengths"] || [],
        requires_attention: result["requires_attention"] || false
      }
    }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse LLM response: #{e.message}")
    Rails.logger.error("Response: #{llm_response}")

    # Fallback на базовый анализ
    {
      score: 50,
      summary: "Ошибка автоматического анализа",
      findings: {
        violations: [{
          category: "Системная ошибка",
          severity: "critical",
          description: "Не удалось выполнить автоматический анализ",
          reference: "",
          recommendation: "Требуется ручная проверка"
        }],
        strengths: [],
        requires_attention: true
      }
    }
  end

  def extract_icd_code(text)
    # Простое извлечение кода МКБ (можно улучшить регуляркой)
    match = text.match(/[A-Z]\d{2}(\.\d{1,2})?/)
    match ? match[0] : nil
  end
end
