# frozen_string_literal: true

# Сервис для извлечения ключевых полей из текста консультативного листа
# Использует регулярные выражения и текстовый парсинг для структурирования данных
class AdvisorySheetFieldExtractionService
  # Маппинг заголовков разделов на названия полей
  FIELD_PATTERNS = {
    complaints: [
      /жалобы[:\s]+(.*?)(?=anamnesis|анамнез|объективн|диагноз|назначени|рекоменд|\z)/mi,
      /жалобы пациента[:\s]+(.*?)(?=anamnesis|анамнез|объективн|диагноз|назначени|рекоменд|\z)/mi
    ],
    anamnesis_morbi: [
      /anamnesis\s+morbi[:\s]+(.*?)(?=anamnesis\s+vitae|объективн|диагноз|назначени|рекоменд|\z)/mi,
      /анамнез\s+заболевания[:\s]+(.*?)(?=анамнез\s+жизни|объективн|диагноз|назначени|рекоменд|\z)/mi,
      /история\s+заболевания[:\s]+(.*?)(?=история\s+жизни|объективн|диагноз|назначени|рекоменд|\z)/mi
    ],
    anamnesis_vitae: [
      /anamnesis\s+vitae[:\s]+(.*?)(?=объективн|диагноз|назначени|рекоменд|протокол|\z)/mi,
      /анамнез\s+жизни[:\s]+(.*?)(?=объективн|диагноз|назначени|рекоменд|протокол|\z)/mi,
      /история\s+жизни[:\s]+(.*?)(?=объективн|диагноз|назначени|рекоменд|протокол|\z)/mi
    ],
    physical_examination: [
      /объективн(?:ый|ого)?\s+(?:осмотр|статус)[:\s]+(.*?)(?=протокол|диагноз|назначени|рекоменд|направлени|\z)/mi,
      /физикальн(?:ый|ого)?\s+осмотр[:\s]+(.*?)(?=протокол|диагноз|назначени|рекоменд|направлени|\z)/mi,
      /status\s+(?:praesens|localis)[:\s]+(.*?)(?=протокол|диагноз|назначени|рекоменд|направлени|\z)/mi
    ],
    study_protocol: [
      /протокол\s+исследования[:\s]+(.*?)(?=диагноз|назначени|рекоменд|направлени|\z)/mi,
      /результат(?:ы)?\s+исследовани(?:й|я)[:\s]+(.*?)(?=диагноз|назначени|рекоменд|направлени|\z)/mi,
      /лабораторн(?:ые|ых)?\s+(?:данные|исследования)[:\s]+(.*?)(?=диагноз|назначени|рекоменд|направлени|\z)/mi
    ],
    referrals: [
      /направлени(?:я|е)[:\s]+(.*?)(?=назначени|рекоменд|диагноз|\z)/mi,
      /консультаци(?:я|и)[:\s]+(.*?)(?=назначени|рекоменд|диагноз|\z)/mi
    ],
    prescriptions: [
      /назначени(?:я|е)[:\s]+(.*?)(?=рекоменд|примечани|\z)/mi,
      /лечение[:\s]+(.*?)(?=рекоменд|примечани|\z)/mi,
      /терапия[:\s]+(.*?)(?=рекоменд|примечани|\z)/mi
    ],
    recommendations: [
      /рекоменд(?:ации|аций)(?:\s+врача)?[:\s]+(.*?)(?=примечани|заключение|notes|\z)/mi,
      /заключение[:\s]+(.*?)(?=примечани|notes|\z)/mi
    ],
    notes: [
      /примечани(?:е|я)[:\s]+(.*?)$/mi,
      /notes?[:\s]+(.*?)$/mi
    ]
  }.freeze

  # Паттерны для извлечения диагнозов
  DIAGNOSIS_PATTERNS = {
    section: /диагноз(?:ы)?[:\s]+(.*?)(?=направлени|назначени|рекоменд|примечани|\z)/mi,
    mkb_code: /(?:код\s+мкб|мкб)[:\s-]*([A-Z]\d{2}(?:\.\d{1,2})?)/i,
    main_disease: /(?:основн(?:ое|ой)\s+заболевани(?:е|я)|клинический\s+диагноз)[:\s-]*(.*?)(?=\(|код|вид|\n|$)/mi,
    diagnosis_type: /(?:вид\s+диагноза|тип)[:\s-]*(.*?)(?=\n|$)/mi
  }.freeze

  class << self
    # Главный метод для извлечения всех полей из текста
    # @param content [String] - текст консультативного листа
    # @return [Hash] - хеш с извлеченными полями
    def extract(content)
      return empty_fields if content.blank?

      normalized_content = normalize_text(content)

      {
        complaints: extract_field(normalized_content, :complaints),
        anamnesis_morbi: extract_field(normalized_content, :anamnesis_morbi),
        anamnesis_vitae: extract_field(normalized_content, :anamnesis_vitae),
        physical_examination: extract_field(normalized_content, :physical_examination),
        study_protocol: extract_field(normalized_content, :study_protocol),
        diagnoses: extract_diagnoses(normalized_content),
        referrals: extract_field(normalized_content, :referrals),
        prescriptions: extract_field(normalized_content, :prescriptions),
        recommendations: extract_field(normalized_content, :recommendations),
        notes: extract_field(normalized_content, :notes)
      }
    end

    private

    # Нормализация текста для улучшения парсинга
    def normalize_text(text)
      text
        .gsub(/\r\n/, "\n")           # Унификация переносов строк
        .gsub(/\t/, " ")              # Табы в пробелы
        .gsub(/[ ]{2,}/, " ")         # Множественные пробелы в один
        .strip
    end

    # Извлекает текст конкретного поля
    def extract_field(content, field_name)
      patterns = FIELD_PATTERNS[field_name]
      return "" unless patterns

      patterns.each do |pattern|
        match = content.match(pattern)
        next unless match

        extracted = match[1]&.strip
        next if extracted.blank?

        # Очищаем от лишних символов и возвращаем
        return clean_extracted_text(extracted)
      end

      ""
    end

    # Извлекает информацию о диагнозах
    def extract_diagnoses(content)
      # Сначала находим секцию диагнозов
      diagnosis_section = content.match(DIAGNOSIS_PATTERNS[:section])
      return {} unless diagnosis_section

      section_text = diagnosis_section[1]&.strip || ""
      return {} if section_text.blank?

      # Извлекаем компоненты диагноза
      {
        "mkb_code" => extract_mkb_code(section_text),
        "main_disease" => extract_main_disease(section_text),
        "diagnosis_type" => extract_diagnosis_type(section_text)
      }.compact
    end

    # Извлекает код МКБ
    def extract_mkb_code(text)
      match = text.match(DIAGNOSIS_PATTERNS[:mkb_code])
      match ? match[1].upcase : ""
    end

    # Извлекает основное заболевание
    def extract_main_disease(text)
      match = text.match(DIAGNOSIS_PATTERNS[:main_disease])
      return "" unless match

      disease = match[1]&.strip
      clean_extracted_text(disease)
    end

    # Извлекает вид диагноза
    def extract_diagnosis_type(text)
      match = text.match(DIAGNOSIS_PATTERNS[:diagnosis_type])
      return "" unless match

      diagnosis_type = match[1]&.strip
      clean_extracted_text(diagnosis_type)
    end

    # Очищает извлеченный текст от лишних символов и форматирования
    def clean_extracted_text(text)
      return "" if text.blank?

      text
        .gsub(/\n{3,}/, "\n\n")       # Множественные переносы строк
        .gsub(/^\s*[-•]\s*/, "")      # Маркеры списков в начале
        .strip
        .truncate(3000)                # Увеличенный лимит для длинных медицинских записей
    end

    # Возвращает пустую структуру полей
    def empty_fields
      {
        complaints: "",
        anamnesis_morbi: "",
        anamnesis_vitae: "",
        physical_examination: "",
        study_protocol: "",
        diagnoses: {},
        referrals: "",
        prescriptions: "",
        recommendations: "",
        notes: ""
      }
    end
  end
end
