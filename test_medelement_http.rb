#!/usr/bin/env ruby
# frozen_string_literal: true

# Тестовый скрипт для проверки работы MedelementScraperService с Net::HTTP

require_relative "config/environment"

puts "=" * 80
puts "Тест MedelementScraperService (Net::HTTP версия)"
puts "=" * 80
puts

# Проверка переменных окружения
if ENV["MEDELEMENT_LOGIN"].blank? || ENV["MEDELEMENT_PASSWORD"].blank?
  puts "❌ ОШИБКА: MEDELEMENT_LOGIN или MEDELEMENT_PASSWORD не установлены"
  puts "Установите эти переменные в файле .env"
  exit 1
end

puts "✓ Переменные окружения настроены"
puts "  Login: #{ENV['MEDELEMENT_LOGIN']}"
puts

# Тест 1: Получение всех специалистов
puts "=" * 80
puts "ТЕСТ 1: Получение списка всех специалистов"
puts "=" * 80
puts

begin
  specialists = MedelementScraperService.fetch_all_specialists

  puts
  puts "=" * 80
  puts "РЕЗУЛЬТАТЫ:"
  puts "=" * 80
  puts "Всего найдено специалистов: #{specialists.size}"
  puts

  if specialists.any?
    puts "Первые 5 специалистов:"
    specialists.first(5).each_with_index do |specialist, index|
      puts "  #{index + 1}. #{specialist[:last_name]} #{specialist[:first_name]} #{specialist[:second_name]}"
      puts "     Email: #{specialist[:email]}"
      puts "     Клиника: #{specialist[:clinic]}"
      puts
    end

    # Сохраняем результаты в JSON файл
    output_file = "medelement_specialists_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(output_file, JSON.pretty_generate(specialists))
    puts "✓ Результаты сохранены в файл: #{output_file}"
  else
    puts "⚠️  Специалисты не найдены"
  end
rescue StandardError => e
  puts
  puts "❌ ОШИБКА при выполнении теста:"
  puts "  Тип: #{e.class}"
  puts "  Сообщение: #{e.message}"
  puts "  Трейс:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end

puts
puts "=" * 80
puts "Тест завершен успешно!"
puts "=" * 80
