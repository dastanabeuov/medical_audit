# frozen_string_literal: true

# Сервис для удаления персональных данных пациента из КЛ
# ВАЖНО: ИИ не должен знать личные данные пациента
class PersonalDataSanitizerService
  # Паттерны для поиска персональных данных
  PATTERNS = {
    # ФИО (полное и частичное)
    full_name: /(?:Пациент|ФИО|Больной)[\s:]*([А-ЯЁа-яё]+[\s*]+[А-ЯЁа-яё*]+[\s*]*[А-ЯЁа-яё*]*)/i,

    # ИИН (12 цифр)
    iin: /\b\d{12}\b/,
    iin_partial: /\b\d{3,4}[\s*]+\d{3,4}[\s*]+\d{3,4}\b/,

    # Телефон
    phone: /(?:\+7|8)[\s\-]?\(?\d{3}\)?[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}/,
    phone_masked: /\+7\s*\d{3}[\s*]+\d{2,5}/,

    # Дата рождения
    birth_date: /(?:дата\s*рождения|д\.р\.|родился|родилась)[\s:]*\d{1,2}[.\-\/]\d{1,2}[.\-\/]\d{2,4}/i,

    # Возраст
    age: /\b\d{1,3}\s*(?:лет|год|года)\b/i,

    # Пол
    gender: /\b(?:МУЖ|ЖЕН|мужской|женский)\b/i,

    # Адрес
    address: /(?:адрес|проживает|прописан)[\s:]*[^\n]+/i,

    # Место работы
    workplace: /(?:место\s*работы|работает)[\s:]*[^\n]+/i
  }.freeze

  # Заголовок КЛ который МОЖНО передавать ИИ (пример из ТЗ)
  # После этого текста начинается медицинская информация
  SAFE_HEADER_END_MARKERS = [
    "Консультативный лист",
    "Advisory sheet",
    "Записи по приему"
  ].freeze

  class << self
    # Основной метод санитизации
    # Возвращает текст БЕЗ персональных данных
    def sanitize(content)
      return "" if content.blank?

      sanitized = content.dup

      # Заменяем ФИО
      sanitized.gsub!(PATTERNS[:full_name]) do |match|
        match.gsub(/[А-ЯЁа-яё]+/) { |name| mask_name(name) }
      end

      # Заменяем ИИН
      sanitized.gsub!(PATTERNS[:iin], "[ИИН СКРЫТ]")
      sanitized.gsub!(PATTERNS[:iin_partial], "[ИИН СКРЫТ]")

      # Заменяем телефон
      sanitized.gsub!(PATTERNS[:phone], "[ТЕЛЕФОН СКРЫТ]")
      sanitized.gsub!(PATTERNS[:phone_masked], "[ТЕЛЕФОН СКРЫТ]")

      # Заменяем дату рождения
      sanitized.gsub!(PATTERNS[:birth_date], "[ДАТА РОЖДЕНИЯ СКРЫТА]")

      # Заменяем адрес
      sanitized.gsub!(PATTERNS[:address], "[АДРЕС СКРЫТ]")

      # Заменяем место работы
      sanitized.gsub!(PATTERNS[:workplace], "[МЕСТО РАБОТЫ СКРЫТО]")

      # Дополнительная очистка замаскированных данных (со звездочками)
      sanitized = clean_masked_data(sanitized)

      sanitized
    end

    # Извлечение только медицинской части КЛ
    def extract_medical_content(content)
      return "" if content.blank?

      # Ищем начало медицинской информации после заголовка
      medical_start = find_medical_start(content)

      if medical_start
        medical_content = content[medical_start..]
        sanitize(medical_content)
      else
        sanitize(content)
      end
    end

    # Извлечение номера записи (recording)
    def extract_recording_number(content)
      match = content.match(/Записи\s+по\s+приему\s*#?\s*(\d+)/i)
      match ? match[1] : nil
    end

    # Извлечение ФИО пациента из КЛ (для использования в качестве имени файла)
    def extract_patient_name(content)
      return nil if content.blank?

      match = content.match(PATTERNS[:full_name])
      return nil unless match

      # Извлекаем только ФИО (группа захвата 1)
      full_name = match[1]

      # Очищаем от лишних пробелов и звездочек
      full_name.gsub(/\s+/, " ").gsub("*", "").strip
    end

    # Извлечение ИИН врача из КЛ (ДО санитизации!)
    # Ищет ИИН после упоминания врача в КЛ
    # @param content [String] - исходный текст КЛ
    # @return [String, nil] - ИИН врача (12 цифр) или nil
    def extract_doctor_iin(content)
      return nil if content.blank?

      # Паттерн: "Врач:", "Доктор:", "Лечащий врач:" и т.д. + ИИН (12 цифр)
      # Ищем в пределах 200 символов после упоминания врача
      doctor_section_pattern = /(?:врач|доктор|лечащий\s+врач|специалист)[\s:]*([^\n]{1,200})/i

      content.scan(doctor_section_pattern) do |match|
        doctor_line = match[0]
        # Ищем 12-значный ИИН в этой строке
        iin_match = doctor_line.match(/\b(\d{12})\b/)
        return iin_match[1] if iin_match
      end

      nil
    end

    private

    def mask_name(name)
      return name if name.length <= 2
      "#{name[0..2]}#{"*" * (name.length - 3)}"
    end

    def clean_masked_data(content)
      # Удаляем уже замаскированные данные (со звездочками)
      content.gsub(/[А-ЯЁа-яё]+\*+[А-ЯЁа-яё]*\**/i, "[ИМЯ СКРЫТО]")
             .gsub(/\d+\*+\d*/i, "[НОМЕР СКРЫТ]")
    end

    def find_medical_start(content)
      # Ищем конец заголовочной части
      # Обычно медицинская информация начинается после строки с датой и врачом

      # Ищем паттерн: дата, время, тип приема
      date_pattern = /\d{1,2}\.\d{1,2}\.\d{4}\s*\(\s*\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}\s*\)/
      match = content.match(date_pattern)

      if match
        # Находим конец строки с информацией о пациенте
        end_of_header = content.index("\n", match.end + 1)
        # Пропускаем еще одну строку (информация о пациенте)
        if end_of_header
          next_line_end = content.index("\n", end_of_header + 1)
          return next_line_end ? next_line_end + 1 : end_of_header + 1
        end
      end

      nil
    end
  end
end
