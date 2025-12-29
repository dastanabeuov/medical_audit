# frozen_string_literal: true

puts "Создание тестовых пользователей..."

# Аудиторы
auditor = Auditor.find_or_initialize_by(email: "auditor@test.kz") do |a|
  a.password = "password123"
  a.password_confirmation = "password123"
  a.first_name = "Эксперт"
  a.last_name = "Аудитор"
  a.position = "Старший аудитор"
  a.main_auditor = true
end
if auditor.new_record?
  auditor.skip_confirmation!
  auditor.save!
  puts "Аудитор создан: #{auditor.email}"
else
  auditor.skip_confirmation!
  auditor.save!
  puts "Аудитор уже существует: #{auditor.email}"
end

# Главные врачи для клиник Medelement
puts "\nСоздание главных врачей для клиник Medelement..."

medelement_clinics = [
  {
    clinic: 'Научно-исследовательский медицинский институт "ЭМИРМЕД" (Розыбакиева, 37в)',
    email: 'kl_nii_emirmed_rozybakineva@medelement.auto',
    first_name: 'Главный',
    last_name: 'Научно-исследовательский'
  },
  {
    clinic: 'Медицинский центр "ЭЛИФ-АЙ" (ТОО "Medical Development", Желтоксан,110)',
    email: 'kl_mc_elif_ay@medelement.auto',
    first_name: 'Главный',
    last_name: 'Медицинский'
  },
  {
    clinic: 'Научно-исследовательский институт "EMIRMED" (Нусупбекова, 26/1)',
    email: 'kl_nii_emirmed_nusupbekova@medelement.auto',
    first_name: 'Главный',
    last_name: 'Научно-исследовательский'
  }
]

medelement_clinics.each do |clinic_data|
  md = MainDoctor.find_or_initialize_by(email: clinic_data[:email]) do |m|
    m.password = "password123"
    m.password_confirmation = "password123"
    m.first_name = clinic_data[:first_name]
    m.last_name = clinic_data[:last_name]
    m.clinic = clinic_data[:clinic]
    m.department = "Администрация"
    m.specialization = "Главный врач"
    m.date_of_employment = Date.today
  end

  if md.new_record?
    md.skip_confirmation!
    md.save!
    puts "✓ Главный врач создан для клиники: #{clinic_data[:clinic]}"
  else
    md.skip_confirmation!
    md.save!
    puts "✓ Главный врач уже существует: #{clinic_data[:clinic]}"
  end
end

puts "=" * 80
puts "Тестовые учетные данные:"
puts "Аудитор: auditor@test.kz / password123"
puts "Главврач: main_doctor@test.kz / password123"
puts "Врач: doctor@test.kz / password123"
puts "=" * 80

# Импорт врачей из CSV (если файл существует)
csv_path = Rails.root.join('db', 'doctors_import.csv')
if File.exist?(csv_path)
  puts "\n✓ Найден CSV файл с врачами: #{csv_path}"
  puts "Запуск импорта врачей из CSV..."

  result = DoctorImportService.import_from_csv

  puts "\nРезультаты импорта из CSV:"
  puts "  Создано новых врачей:    #{result[:created]}"
  puts "  Обновлено врачей:        #{result[:updated]}"
  puts "  Ошибок:                  #{result[:failed]}"

  if result[:failed] > 0
    puts "\nОшибки импорта:"
    result[:errors].first(5).each do |error|
      puts "  - #{error[:email]}: #{error[:error]}"
    end
  end

  puts "=" * 80
else
  puts "\n⚠️  CSV файл не найден: #{csv_path}"
  puts "Для создания CSV файла выполните импорт из Medelement:"
  puts "  rails doctors:import_from_medelement"
  puts "=" * 80
end
