# frozen_string_literal: true

# Сервис для управления аккаунтами врачей
class DoctorAccountService
  DEFAULT_PASSWORD = "Qq123456!"
  FALLBACK_EMAIL_DOMAIN = "@emirmed.kz"

  # Маппинг казахских букв на русские для поиска
  KAZAKH_TO_RUSSIAN = {
    'ә' => 'а', 'Ә' => 'А',
    'ғ' => 'г', 'Ғ' => 'Г',
    'қ' => 'к', 'Қ' => 'К',
    'ң' => 'н', 'Ң' => 'Н',
    'ө' => 'о', 'Ө' => 'О',
    'ұ' => 'у', 'Ұ' => 'У',
    'ү' => 'у', 'Ү' => 'У',
    'һ' => 'х', 'Һ' => 'Х',
    'і' => 'и', 'І' => 'И'
  }.freeze

  class << self
    # Найти или создать врача
    # @param doctor_data [Hash] - данные врача
    # @return [Doctor] - найденный или созданный врач
    def find_or_create(doctor_data)
      return nil if doctor_data.blank?

      search_name = [ doctor_data[:last_name], doctor_data[:first_name], doctor_data[:second_name] ].compact.join(" ")
      Rails.logger.info("🔍 Поиск врача: #{search_name}")

      # ШАГ 1: Поиск по email в базе данных (БЫСТРО)
      if doctor_data[:email].present?
        Rails.logger.info("  ШАГ 1: Поиск в БД по email: #{doctor_data[:email]}")
        doctor = Doctor.find_by(email: doctor_data[:email])
        if doctor
          Rails.logger.info("  ✓ ШАГ 1: Найден в БД по email: #{doctor.full_name} (#{doctor.email})")
          # Обновляем данные если они пустые/стандартные
          update_doctor_if_needed(doctor, doctor_data)
          return doctor
        end
        Rails.logger.info("  ✗ ШАГ 1: Не найден по email")
      else
        Rails.logger.info("  ⊗ ШАГ 1: Пропущен (email не указан)")
      end

      # ШАГ 2: Поиск по ФИО в базе данных (БЫСТРО)
      Rails.logger.info("  ШАГ 2: Поиск в БД по ФИО: #{search_name}")
      doctor = find_by_name(doctor_data)
      if doctor
        Rails.logger.info("  ✓ ШАГ 2: Найден в БД по ФИО: #{doctor.full_name} (#{doctor.email})")
        # Обновляем данные если они пустые/стандартные
        update_doctor_if_needed(doctor, doctor_data)
        return doctor
      end
      Rails.logger.info("  ✗ ШАГ 2: Не найден по ФИО в БД")

      # ШАГ 3: Поиск в medelement.com (МЕДЛЕННО - только если не нашли в БД)
      Rails.logger.info("  ШАГ 3: Поиск в medelement.com...")
      medelement_data = find_in_medelement(doctor_data)
      if medelement_data
        Rails.logger.info("  ✓ ШАГ 3: Найден в medelement.com: #{medelement_data[:email]}")
        # Создаем врача на основе данных из medelement
        doctor = create_from_medelement(medelement_data)
        return doctor if doctor
      end
      Rails.logger.info("  ✗ ШАГ 3: Не найден в medelement.com")

      # ШАГ 4: Создаем нового врача с автогенерацией
      Rails.logger.info("  ШАГ 4: Создание нового врача с автогенерированным email")
      create_doctor(doctor_data)
    end

    # Привязать врача к консультативному листу
    # @param doctor [Doctor] - врач
    # @param verified_sheet [VerifiedAdvisorySheet] - проверенный КЛ
    def link_to_advisory_sheet(doctor, verified_sheet)
      return if doctor.blank? || verified_sheet.blank?

      # Проверяем, не привязан ли уже
      return if verified_sheet.doctors.include?(doctor)

      # Создаем связь
      verified_sheet.doctors << doctor
    end

    private

    # Нормализация текста (замена казахских букв на русские)
    def normalize_text(text)
      return nil if text.blank?

      normalized = text.dup
      KAZAKH_TO_RUSSIAN.each do |kaz, rus|
        normalized.gsub!(kaz, rus)
      end
      normalized
    end

    # Поиск врача в medelement.com по ФИО
    # @param doctor_data [Hash] - данные врача для поиска
    # @return [Hash, nil] - данные врача из medelement или nil
    def find_in_medelement(doctor_data)
      return nil if doctor_data[:last_name].blank? || doctor_data[:first_name].blank?

      # Формируем имя для логирования
      search_name = [ doctor_data[:last_name], doctor_data[:first_name], doctor_data[:second_name] ]
                      .compact
                      .join(" ")
                      .strip

      Rails.logger.info("Searching for doctor in medelement.com: #{search_name}")

      begin
        # Используем метод find_doctor из MedelementScraperService
        # ВАЖНО: передаем Hash, а не строку!
        result = MedelementScraperService.find_doctor(doctor_data)

        if result
          Rails.logger.info("✓ Found doctor in medelement.com: #{result[:email]}")
          result
        else
          Rails.logger.info("✗ Doctor not found in medelement.com")
          nil
        end
      rescue StandardError => e
        Rails.logger.error("Error searching in medelement.com: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
        nil
      end
    end

    # Создание врача на основе данных из medelement.com
    # @param medelement_data [Hash] - данные врача из medelement
    # @return [Doctor, nil] - созданный врач или nil
    def create_from_medelement(medelement_data)
      # Ищем главного врача по названию клиники
      main_doctor = find_main_doctor_by_clinic(medelement_data[:clinic])

      doctor_attributes = {
        email: medelement_data[:email],
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD,
        first_name: medelement_data[:first_name],
        last_name: medelement_data[:last_name],
        second_name: medelement_data[:second_name] || "Не указано",
        department: medelement_data[:department] || "Не указано",
        specialization: medelement_data[:specialization] || "Не указано",
        clinic: medelement_data[:clinic] || "Не указано",
        date_of_employment: Time.current,
        doctor_identifier: generate_doctor_identifier(medelement_data),
        main_doctor: main_doctor
      }

      doctor = Doctor.new(doctor_attributes)
      doctor.skip_confirmation!

      if doctor.save
        if main_doctor
          Rails.logger.info("✓ Created doctor from medelement.com: #{doctor.full_name} (#{doctor.email}) → КЛ: #{main_doctor.full_name}")
        else
          Rails.logger.info("✓ Created doctor from medelement.com: #{doctor.full_name} (#{doctor.email}) → КЛ: не найден")
        end
        doctor
      else
        Rails.logger.error("Failed to create doctor from medelement: #{doctor.errors.full_messages.join(", ")}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Error creating doctor from medelement: #{e.message}")
      nil
    end

    # Обновляет данные врача если они пустые или "Не указано"
    def update_doctor_if_needed(doctor, new_data)
      updated = false

      # Обновляем специализацию если она пустая
      if should_update_field?(doctor.specialization) && new_data[:specialization].present?
        doctor.specialization = new_data[:specialization]
        updated = true
      end

      # Обновляем отделение если оно пустое
      if should_update_field?(doctor.department) && new_data[:department].present?
        doctor.department = new_data[:department]
        updated = true
      end

      # Обновляем клинику если она пустая
      if should_update_field?(doctor.clinic) && new_data[:clinic].present?
        doctor.clinic = new_data[:clinic]
        updated = true
      elsif should_update_field?(doctor.clinic) && new_data[:department].present?
        doctor.clinic = extract_clinic_from_department(new_data[:department])
        updated = true
      end

      # Сохраняем изменения если были обновления
      if updated
        doctor.save
        Rails.logger.info("Updated doctor #{doctor.id}: specialization=#{doctor.specialization}, department=#{doctor.department}")
      end

      doctor
    end

    # Проверяет нужно ли обновить поле
    def should_update_field?(value)
      value.nil? || value.blank? || value == "Не указано" || value == "Неизвестно"
    end

    # Поиск врача по ФИО
    def find_by_name(doctor_data)
      return nil if doctor_data[:last_name].blank? || doctor_data[:first_name].blank?

      last_name = doctor_data[:last_name]
      first_name = doctor_data[:first_name]
      second_name = doctor_data[:second_name]

      # СТРАТЕГИЯ 1: Точное совпадение (фамилия + имя + отчество)
      if second_name.present?
        doctor = Doctor.where(
          last_name: last_name,
          first_name: first_name,
          second_name: second_name
        ).first
        return doctor if doctor
      end

      # СТРАТЕГИЯ 2: Поиск по фамилии + имени (игнорируем отчество)
      # Находим врачей с такой же фамилией и именем
      candidates = Doctor.where(
        last_name: last_name,
        first_name: first_name
      )

      # Если передано отчество, но точного совпадения нет - ищем без отчества
      if second_name.present?
        # Ищем врачей у которых отчество не указано (nil или "Не указано")
        doctor = candidates.where(
          "second_name IS NULL OR second_name = '' OR second_name = 'Не указано' OR second_name = 'Неизвестно'"
        ).first
        return doctor if doctor
      end

      # Возвращаем первого найденного
      doctor = candidates.first
      return doctor if doctor

      # СТРАТЕГИЯ 3: Поиск с нормализацией казахских букв
      # Нормализуем входные данные (казахские буквы → русские)
      normalized_last_name = normalize_text(last_name)
      normalized_first_name = normalize_text(first_name)
      normalized_second_name = normalize_text(second_name)

      Rails.logger.debug("  СТРАТЕГИЯ 3: Поиск с нормализацией казахских букв")
      Rails.logger.debug("    Оригинал: #{last_name} #{first_name} #{second_name}")
      Rails.logger.debug("    Нормализовано: #{normalized_last_name} #{normalized_first_name} #{normalized_second_name}")

      # Если нормализация изменила имя - ищем еще раз
      if normalized_first_name != first_name || normalized_last_name != last_name || normalized_second_name != second_name
        # Поиск по нормализованным данным
        if normalized_second_name.present?
          doctor = Doctor.where(
            last_name: normalized_last_name,
            first_name: normalized_first_name,
            second_name: normalized_second_name
          ).first
          return doctor if doctor
        end

        # Поиск по фамилии+имени (нормализованные)
        candidates = Doctor.where(
          last_name: normalized_last_name,
          first_name: normalized_first_name
        )
        return candidates.first if candidates.any?
      end

      nil
    end

    # Создание нового врача
    def create_doctor(doctor_data)
      # Генерируем email если отсутствует
      email = doctor_data[:email].presence || generate_fallback_email

      # Определяем клинику
      clinic = doctor_data[:clinic].presence || extract_clinic_from_department(doctor_data[:department])

      # Ищем главного врача по клинике
      main_doctor = find_main_doctor_by_clinic(clinic)

      # Заполняем обязательные поля значениями по умолчанию, если они отсутствуют
      # ВАЖНО: Если данные пришли из DoctorDataExtractorService, они уже содержат specialization и department
      doctor_attributes = {
        email: email,
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD,
        first_name: doctor_data[:first_name] || "Неизвестно",
        last_name: doctor_data[:last_name] || "Неизвестно",
        second_name: doctor_data[:second_name] || "Неизвестно",
        department: doctor_data[:department].presence || "Не указано",
        specialization: doctor_data[:specialization].presence || "Не указано",
        clinic: clinic,
        date_of_employment: doctor_data[:date_of_employment] || Time.current,
        doctor_identifier: generate_doctor_identifier(doctor_data),
        main_doctor: main_doctor
      }

      # Пропускаем подтверждение email при создании
      doctor = Doctor.new(doctor_attributes)
      doctor.skip_confirmation!

      if doctor.save
        if main_doctor
          Rails.logger.info("Created doctor: #{doctor.full_name} (#{doctor.email}) → КЛ: #{main_doctor.full_name}")
        else
          Rails.logger.info("Created doctor: #{doctor.full_name} (#{doctor.email}) → КЛ: не найден")
        end
        doctor
      else
        Rails.logger.error("Failed to create doctor: #{doctor.errors.full_messages.join(", ")}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Error creating doctor: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      nil
    end

    # Генерация fallback email
    def generate_fallback_email
      # Используем транзакцию для предотвращения race condition
      Doctor.transaction do
        # Находим всех врачей с автогенерированными email
        doctors_with_auto_email = Doctor.where("email LIKE ?", "doctor-%#{FALLBACK_EMAIL_DOMAIN}")
                                       .lock
                                       .pluck(:email)

        # Извлекаем все номера
        numbers = doctors_with_auto_email.map do |email|
          match = email.match(/doctor-(\d+)@/)
          match ? match[1].to_i : 0
        end

        # Находим максимальный номер и увеличиваем на 1
        max_number = numbers.max || 0
        number = max_number + 1

        "doctor-#{number}#{FALLBACK_EMAIL_DOMAIN}"
      end
    rescue StandardError => e
      # Fallback на timestamp если что-то пошло не так
      Rails.logger.error("Error generating fallback email: #{e.message}")
      "doctor-#{Time.current.to_i}#{FALLBACK_EMAIL_DOMAIN}"
    end

    # Генерация идентификатора врача
    def generate_doctor_identifier(doctor_data)
      # Используем первые буквы ФИО + timestamp
      first_letter = doctor_data[:first_name]&.first || "X"
      last_letter = doctor_data[:last_name]&.first || "X"
      timestamp = Time.current.to_i

      "#{last_letter}#{first_letter}-#{timestamp}"
    end

    # Извлекает название клиники из отделения (fallback)
    def extract_clinic_from_department(department)
      return "Не указано" if department.blank?

      # Если отделение указано, используем его как базу для клиники
      "Медицинский центр (#{department})"
    end

    # Поиск главного врача по названию клиники
    # @param clinic_name [String] - название клиники
    # @return [MainDoctor, nil] - найденный главный врач или nil
    def find_main_doctor_by_clinic(clinic_name)
      return nil if clinic_name.blank? || clinic_name == "Не указано"

      # Ищем по точному совпадению
      main_doctor = MainDoctor.find_by(clinic: clinic_name)

      if main_doctor
        Rails.logger.debug("✓ Найден главный врач для клиники '#{clinic_name}': #{main_doctor.full_name}")
      else
        Rails.logger.debug("✗ Главный врач для клиники '#{clinic_name}' не найден")
      end

      main_doctor
    end
  end
end
