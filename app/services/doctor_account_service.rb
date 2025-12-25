# frozen_string_literal: true

# Сервис для управления аккаунтами врачей
class DoctorAccountService
  DEFAULT_PASSWORD = "Qq123456!"
  FALLBACK_EMAIL_DOMAIN = "@emirmed.kz"

  class << self
    # Найти или создать врача
    # @param doctor_data [Hash] - данные врача
    # @return [Doctor] - найденный или созданный врач
    def find_or_create(doctor_data)
      return nil if doctor_data.blank?

      # Сначала пытаемся найти врача по email
      if doctor_data[:email].present?
        doctor = Doctor.find_by(email: doctor_data[:email])
        if doctor
          # Обновляем данные если они пустые/стандартные
          update_doctor_if_needed(doctor, doctor_data)
          return doctor
        end
      end

      # Затем пытаемся найти по ФИО
      doctor = find_by_name(doctor_data)
      if doctor
        # Обновляем данные если они пустые/стандартные
        update_doctor_if_needed(doctor, doctor_data)
        return doctor
      end

      # Создаем нового врача
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

      query = Doctor.where(
        last_name: doctor_data[:last_name],
        first_name: doctor_data[:first_name]
      )

      # Если есть отчество, добавляем его в поиск
      if doctor_data[:second_name].present?
        query = query.where(second_name: doctor_data[:second_name])
      end

      query.first
    end

    # Создание нового врача
    def create_doctor(doctor_data)
      # Генерируем email если отсутствует
      email = doctor_data[:email].presence || generate_fallback_email

      # Заполняем обязательные поля значениями по умолчанию, если они отсутствуют
      # ВАЖНО: Если данные пришли из DoctorDataExtractorService, они уже содержат specialization и department
      doctor_attributes = {
        email: email,
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD,
        first_name: doctor_data[:first_name] || "Неизвестно",
        last_name: doctor_data[:last_name] || "Неизвестно",
        second_name: doctor_data[:second_name],
        department: doctor_data[:department].presence || "Не указано",
        specialization: doctor_data[:specialization].presence || "Не указано",
        clinic: doctor_data[:clinic].presence || extract_clinic_from_department(doctor_data[:department]),
        date_of_employment: doctor_data[:date_of_employment] || Time.current,
        doctor_identifier: generate_doctor_identifier(doctor_data)
      }

      # Пропускаем подтверждение email при создании
      doctor = Doctor.new(doctor_attributes)
      doctor.skip_confirmation!

      if doctor.save
        Rails.logger.info("Created doctor: #{doctor.full_name} (#{doctor.email})")
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
        # Находим последний номер с блокировкой
        last_doctor = Doctor.where("email LIKE ?", "doctor-%#{FALLBACK_EMAIL_DOMAIN}")
                           .order("SUBSTRING(email FROM 'doctor-(\\d+)@')::integer DESC NULLS LAST")
                           .lock
                           .first

        if last_doctor
          # Извлекаем номер и увеличиваем
          match = last_doctor.email.match(/doctor-(\d+)@/)
          number = match ? match[1].to_i + 1 : 1
        else
          number = 1
        end

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
  end
end
