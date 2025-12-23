# frozen_string_literal: true

puts "Создание тестовых пользователей..."

# Аудиторы
auditor = Auditor.find_or_create_by!(email: "auditor@test.kz") do |a|
  a.password = "password123"
  a.password_confirmation = "password123"
  a.first_name = "Тест"
  a.last_name = "Аудитор"
  a.position = "Старший аудитор"
  a.main_auditor = true
end
auditor.skip_confirmation!
auditor.save!
puts "Аудитор создан: #{auditor.email}"

# Главные врачи
main_doctor = MainDoctor.find_or_create_by!(email: "main_doctor@test.kz") do |md|
  md.password = "password123"
  md.password_confirmation = "password123"
  md.first_name = "Тест"
  md.last_name = "Главврач"
  md.department = "Терапия"
  md.specialization = "Терапевт"
  md.clinic = "Желтоксан"
  md.date_of_employment = "10.08.2025"
end
main_doctor.skip_confirmation!
main_doctor.save!
puts "Главный врач создан: #{main_doctor.email}"

# Врачи
doctor = Doctor.find_or_create_by!(email: "doctor@test.kz") do |d|
  d.password = "password123"
  d.password_confirmation = "password123"
  d.first_name = "Тест"
  d.last_name = "Врач"
  d.specialization = "Терапевт"
  d.department = "Терапия"
  d.clinic = "Желтоксан"
  d.date_of_employment = "10.02.2025"
  d.main_doctor = main_doctor
end
doctor.skip_confirmation!
doctor.save!
puts "Врач создан: #{doctor.email}"

puts "=" * 50
puts "Тестовые учетные данные:"
puts "Аудитор: auditor@test.kz / password123"
puts "Главврач: main_doctor@test.kz / password123"
puts "Врач: doctor@test.kz / password123"
puts "=" * 50
