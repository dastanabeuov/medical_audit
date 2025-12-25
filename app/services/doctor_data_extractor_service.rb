# frozen_string_literal: true

# Сервис для извлечения данных врача из консультативного листа
class DoctorDataExtractorService
  # Паттерны для поиска ФИО врача
  DOCTOR_PATTERNS = [
    # Стандартные паттерны: "Врач:", "Доктор:", "Лечащий врач:"
    /(?:Врач|Доктор|Лечащий\s+врач|Специалист)[\s:]+([А-ЯЁ][а-яё]+\s+[А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+)?)/i,
    /(?:Провел\s+консультацию|Принимающий\s+врач)[\s:]+([А-ЯЁ][а-яё]+\s+[А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+)?)/i,

    # Паттерны со специальностями: "Педиатр:", "Уролог:", "Терапевт:" и т.д.
    /(?:Педиатр|Уролог|Терапевт|Хирург|Кардиолог|Невролог|Офтальмолог|Отоларинголог|Гинеколог|Дерматолог|Эндокринолог|Гастроэнтеролог|Пульмонолог|Нефролог|Ревматолог|Онколог|Психиатр|Психолог|Стоматолог|Ортопед|Травматолог)[\s:]+([А-ЯЁ][а-яё]+\s+[А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+)?)/i
  ].freeze

  class << self
    # Основной метод извлечения данных врача
    # @param content [String] - текст консультативного листа
    # @return [Hash] - { full_name:, first_name:, last_name:, second_name:, specialization:, department: }
    def extract(content)
      return default_result if content.blank?

      doctor_info = extract_doctor_info(content)

      if doctor_info[:full_name].present?
        parse_full_name(doctor_info[:full_name]).merge(
          specialization: doctor_info[:specialization],
          department: doctor_info[:department]
        )
      else
        default_result
      end
    end

    private

    # Возвращает пустой результат по умолчанию
    def default_result
      {
        full_name: nil,
        first_name: nil,
        last_name: nil,
        second_name: nil,
        specialization: nil,
        department: nil
      }
    end

    # Извлечение полной информации о враче из текста
    # Формат: "Педиатр: Амренова Мадина (кабинет "Педиатр" )"
    def extract_doctor_info(content)
      result = { full_name: nil, specialization: nil, department: nil }

      DOCTOR_PATTERNS.each do |pattern|
        match = content.match(pattern)
        next unless match && match[1]

        # Очищаем от лишних символов и пробелов
        name = match[1].strip.gsub(/[*\d]/, "").gsub(/\s+/, " ")
        next if name.blank?

        result[:full_name] = name

        # Извлекаем специализацию (то, что было перед именем)
        # Ищем слово перед двоеточием в найденном совпадении
        full_match = match[0]
        specialization_match = full_match.match(/^([А-ЯЁа-яё]+)[\s:]+/)
        result[:specialization] = specialization_match[1] if specialization_match

        # Извлекаем отделение из части "(кабинет "...")"
        # Ищем после имени врача до конца строки или до следующей секции
        after_name = content[match.end(1)..-1]

        # Паттерн для "(кабинет "Педиатр" )" или "(кабинет 'Педиатр' )"
        department_match = after_name&.match(/\(кабинет\s+["']([^"']+)["']\s*\)/i)
        if department_match
          result[:department] = department_match[1]
        else
          # Альтернативный паттерн: просто "кабинет Педиатр" без кавычек
          department_match = after_name&.match(/\(кабинет\s+([^\)]+)\)/i)
          result[:department] = department_match[1].strip if department_match
        end

        # Если отделение не найдено, используем специализацию
        result[:department] ||= result[:specialization]

        break if result[:full_name].present?
      end

      result
    end

    # Разбор полного имени на компоненты
    # Формат: "Фамилия Имя Отчество" или "Фамилия Имя"
    def parse_full_name(full_name)
      parts = full_name.split(/\s+/)

      case parts.length
      when 3
        # Фамилия Имя Отчество
        {
          full_name: full_name,
          last_name: parts[0],
          first_name: parts[1],
          second_name: parts[2]
        }
      when 2
        # Фамилия Имя
        {
          full_name: full_name,
          last_name: parts[0],
          first_name: parts[1],
          second_name: nil
        }
      else
        # Неожиданный формат
        {
          full_name: full_name,
          last_name: parts[0],
          first_name: parts[1..-1]&.join(" "),
          second_name: nil
        }
      end
    end
  end
end
