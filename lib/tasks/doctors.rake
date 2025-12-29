# frozen_string_literal: true

# rails doctors:import_from_medelement
namespace :doctors do
  desc "Импорт специалистов с medelement.com"
  task import_from_medelement: :environment do
    puts "=" * 80
    puts "Начало импорта специалистов с medelement.com"
    puts "=" * 80
    puts ""

    # Проверяем наличие переменных окружения
    unless ENV["MEDELEMENT_LOGIN"].present? && ENV["MEDELEMENT_PASSWORD"].present?
      puts "ОШИБКА: Не установлены переменные окружения MEDELEMENT_LOGIN и MEDELEMENT_PASSWORD"
      puts "Пожалуйста, добавьте их в .env файл:"
      puts "  MEDELEMENT_LOGIN=your_email@example.com"
      puts "  MEDELEMENT_PASSWORD=your_password"
      exit 1
    end

    # Запускаем импорт
    result = DoctorImportService.import_from_medelement

    # Выводим результаты
    puts ""
    puts "=" * 80
    puts "Результаты импорта:"
    puts "=" * 80
    puts "Создано новых врачей:    #{result[:created]}"
    puts "Обновлено врачей:        #{result[:updated]}"
    puts "Ошибок:                  #{result[:failed]}"
    puts ""

    if result[:errors].any?
      puts "Детали ошибок:"
      puts "-" * 80
      result[:errors].each_with_index do |error, index|
        puts "#{index + 1}. Email: #{error[:email]}"
        puts "   Ошибка: #{error[:error]}"
        puts ""
      end
    end

    puts "Импорт завершен!"
    puts "=" * 80
  end

  desc "Импорт специалистов с привязкой к главному врачу"
  task :import_with_main_doctor, [ :email ] => :environment do |_t, args|
    unless args[:email]
      puts "ОШИБКА: Необходимо указать email главного врача"
      puts "Использование: rake doctors:import_with_main_doctor[main_doctor@example.com]"
      exit 1
    end

    # Ищем главного врача
    main_doctor = MainDoctor.find_by(email: args[:email])

    unless main_doctor
      puts "ОШИБКА: Главный врач с email '#{args[:email]}' не найден"
      exit 1
    end

    puts "=" * 80
    puts "Начало импорта специалистов с привязкой к главному врачу:"
    puts "  #{main_doctor.full_name} (#{main_doctor.email})"
    puts "=" * 80
    puts ""

    # Запускаем импорт с привязкой
    result = DoctorImportService.import_from_medelement(main_doctor: main_doctor)

    # Выводим результаты
    puts ""
    puts "=" * 80
    puts "Результаты импорта:"
    puts "=" * 80
    puts "Создано новых врачей:    #{result[:created]}"
    puts "Обновлено врачей:        #{result[:updated]}"
    puts "Ошибок:                  #{result[:failed]}"
    puts ""

    if result[:errors].any?
      puts "Детали ошибок:"
      puts "-" * 80
      result[:errors].each_with_index do |error, index|
        puts "#{index + 1}. Email: #{error[:email]}"
        puts "   Ошибка: #{error[:error]}"
        puts ""
      end
    end

    puts "Импорт завершен!"
    puts "=" * 80
  end

  desc "Тестовое получение списка специалистов (без сохранения в БД)"
  task test_fetch_specialists: :environment do
    puts "=" * 80
    puts "Тестовое получение списка специалистов с medelement.com"
    puts "=" * 80
    puts ""

    specialists = MedelementScraperService.fetch_all_specialists

    puts "Найдено специалистов: #{specialists.size}"
    puts ""

    if specialists.any?
      puts "Примеры найденных специалистов:"
      puts "-" * 80
      specialists.first(5).each_with_index do |specialist, index|
        puts "#{index + 1}. #{specialist[:last_name]} #{specialist[:first_name]} #{specialist[:second_name]}"
        puts "   Email: #{specialist[:email]}"
        puts "   Клиника: #{specialist[:clinic]}"
        puts ""
      end

      if specialists.size > 5
        puts "... и еще #{specialists.size - 5} специалистов"
      end
    else
      puts "Специалисты не найдены. Проверьте настройки авторизации."
    end

    puts "=" * 80
  end
  # rails doctors:export_to_csv
  desc "Экспорт всех врачей в CSV файл"
  task export_to_csv: :environment do
    puts "=" * 80
    puts "Экспорт врачей в CSV"
    puts "=" * 80
    puts ""

    doctors = Doctor.all
    puts "Всего врачей в БД: #{doctors.count}"

    specialists_data = doctors.map do |doctor|
      {
        email: doctor.email,
        first_name: doctor.first_name,
        last_name: doctor.last_name,
        second_name: doctor.second_name,
        clinic: doctor.clinic,
        department: doctor.department,
        specialization: doctor.specialization
      }
    end

    csv_path = DoctorImportService::CSV_FILE_PATH
    DoctorImportService.export_to_csv(specialists_data)

    puts "✓ Экспорт завершен"
    puts "Файл сохранен: #{csv_path}"
    puts "Размер файла: #{(File.size(csv_path) / 1024.0).round(2)} KB"
    puts "=" * 80
  end

  desc "Импорт врачей из CSV файла"
  task import_from_csv: :environment do
    puts "=" * 80
    puts "Импорт врачей из CSV"
    puts "=" * 80
    puts ""

    result = DoctorImportService.import_from_csv

    puts "=" * 80
    puts "Результаты импорта:"
    puts "=" * 80
    puts "Создано новых врачей:    #{result[:created]}"
    puts "Обновлено врачей:        #{result[:updated]}"
    puts "Ошибок:                  #{result[:failed]}"
    puts ""

    if result[:errors].any?
      puts "Детали ошибок:"
      puts "-" * 80
      result[:errors].first(5).each_with_index do |error, index|
        puts "#{index + 1}. Email: #{error[:email]}"
        puts "   Ошибка: #{error[:error]}"
        puts ""
      end
    end

    puts "Импорт завершен!"
    puts "=" * 80
  end
end
