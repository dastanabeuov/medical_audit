# frozen_string_literal: true

require 'csv'

# Сервис для импорта врачей из данных medelement.com
class DoctorImportService
  CSV_FILE_PATH = Rails.root.join('db', 'doctors_import.csv').freeze
  class << self
    # Импорт всех специалистов с medelement.com
    # @param main_doctor [MainDoctor, nil] - главный врач для привязки (опционально)
    # @return [Hash] - результат импорта { created: N, updated: N, failed: N, errors: [] }
    def import_from_medelement(main_doctor: nil)
      result = {
        created: 0,
        updated: 0,
        failed: 0,
        errors: []
      }

      Rails.logger.info("Начало импорта специалистов с medelement.com")

      # Получаем список специалистов
      specialists = MedelementScraperService.fetch_all_specialists

      if specialists.empty?
        Rails.logger.warn("Не найдено ни одного специалиста для импорта")
        return result
      end

      Rails.logger.info("Найдено специалистов для импорта: #{specialists.size}")

      # Создаем или обновляем врачей
      specialists.each_with_index do |specialist_data, index|
        begin
          doctor = create_or_update_doctor(specialist_data, main_doctor)

          if doctor.persisted?
            if doctor.previously_new_record?
              result[:created] += 1
              Rails.logger.info("[#{index + 1}/#{specialists.size}] Создан врач: #{doctor.full_name} (#{doctor.email})")
            else
              result[:updated] += 1
              Rails.logger.info("[#{index + 1}/#{specialists.size}] Обновлен врач: #{doctor.full_name} (#{doctor.email})")
            end
          else
            result[:failed] += 1
            error_msg = "Ошибка сохранения: #{doctor.errors.full_messages.join(', ')}"
            result[:errors] << { email: specialist_data[:email], error: error_msg }
            Rails.logger.error("[#{index + 1}/#{specialists.size}] #{error_msg}")
          end
        rescue StandardError => e
          result[:failed] += 1
          error_msg = "#{e.class}: #{e.message}"
          result[:errors] << { email: specialist_data[:email], error: error_msg }
          Rails.logger.error("[#{index + 1}/#{specialists.size}] Ошибка импорта: #{error_msg}")
        end
      end

      Rails.logger.info("Импорт завершен. Создано: #{result[:created]}, Обновлено: #{result[:updated]}, Ошибок: #{result[:failed]}")

      # Экспортируем данные в CSV для быстрой загрузки в разработке
      Rails.logger.info("Экспорт данных в CSV файл: #{CSV_FILE_PATH}")
      export_to_csv(specialists)
      Rails.logger.info("✓ Экспорт в CSV завершен")

      result
    end

    # Импорт врачей из CSV файла (для быстрой загрузки в разработке)
    # @return [Hash] - результат импорта { created: N, updated: N, failed: N, errors: [] }
    def import_from_csv
      result = {
        created: 0,
        updated: 0,
        failed: 0,
        errors: []
      }

      unless File.exist?(CSV_FILE_PATH)
        Rails.logger.warn("CSV файл не найден: #{CSV_FILE_PATH}")
        return result
      end

      Rails.logger.info("Начало импорта врачей из CSV: #{CSV_FILE_PATH}")

      CSV.foreach(CSV_FILE_PATH, headers: true, encoding: 'UTF-8') do |row|
        begin
          specialist_data = {
            email: row['email'],
            first_name: row['first_name'],
            last_name: row['last_name'],
            second_name: row['second_name'],
            clinic: row['clinic'],
            department: row['department'],
            specialization: row['specialization']
          }

          doctor = create_or_update_doctor(specialist_data, nil)

          if doctor.persisted?
            if doctor.previously_new_record?
              result[:created] += 1
            else
              result[:updated] += 1
            end
          else
            result[:failed] += 1
            result[:errors] << { email: specialist_data[:email], error: doctor.errors.full_messages.join(', ') }
          end
        rescue StandardError => e
          result[:failed] += 1
          result[:errors] << { email: row['email'], error: "#{e.class}: #{e.message}" }
          Rails.logger.error("Ошибка импорта из CSV (строка #{row.line}): #{e.message}")
        end
      end

      Rails.logger.info("Импорт из CSV завершен. Создано: #{result[:created]}, Обновлено: #{result[:updated]}, Ошибок: #{result[:failed]}")

      result
    end

    # Экспорт данных врачей в CSV файл
    # @param specialists [Array<Hash>] - массив данных специалистов
    def export_to_csv(specialists)
      CSV.open(CSV_FILE_PATH, 'w', encoding: 'UTF-8') do |csv|
        # Заголовки
        csv << %w[email first_name last_name second_name clinic department specialization]

        # Данные
        specialists.each do |specialist|
          csv << [
            specialist[:email],
            specialist[:first_name],
            specialist[:last_name],
            specialist[:second_name],
            specialist[:clinic],
            specialist[:department],
            specialist[:specialization]
          ]
        end
      end
    end

    # Создание или обновление врача на основе данных
    # @param specialist_data [Hash] - данные специалиста
    # @param main_doctor [MainDoctor, nil] - главный врач для привязки
    # @return [Doctor] - созданный или обновленный врач
    def create_or_update_doctor(specialist_data, main_doctor = nil)
      # Ищем существующего врача по email
      doctor = Doctor.find_or_initialize_by(email: specialist_data[:email])

      # Пропускаем валидацию пароля для существующих записей
      skip_password = doctor.persisted?

      # Если main_doctor не передан, пытаемся найти по названию клиники
      if main_doctor.nil? && specialist_data[:clinic].present?
        main_doctor = MainDoctor.find_by(clinic: specialist_data[:clinic])
      end

      # Заполняем данные
      doctor.assign_attributes(
        first_name: specialist_data[:first_name],
        last_name: specialist_data[:last_name],
        second_name: specialist_data[:second_name],
        clinic: specialist_data[:clinic],
        department: specialist_data[:department] || "Не указано",
        specialization: specialist_data[:specialization] || "Не указано",
        main_doctor: main_doctor
      )

      # Устанавливаем дату трудоустройства только для новых записей
      if doctor.new_record?
        doctor.date_of_employment = Date.today
        # Генерируем временный пароль для новых врачей
        doctor.password = SecureRandom.hex(16)
        doctor.skip_confirmation! # Пропускаем подтверждение email
      end

      # Сохраняем врача
      if skip_password
        doctor.save(validate: false) # Пропускаем валидацию для обновления
        doctor.reload
      else
        doctor.save!
      end

      doctor
    end
  end
end
