#!/usr/bin/env ruby
# Тестовый скрипт для проверки MedelementScraperService

require_relative "config/environment"

puts "=" * 80
puts "Тест MedelementScraperService"
puts "=" * 80
puts ""

# Проверка ENV
puts "Проверка переменных окружения:"
puts "  MEDELEMENT_LOGIN: #{ENV['MEDELEMENT_LOGIN'].present? ? '✓ установлено' : '✗ не установлено'}"
puts "  MEDELEMENT_PASSWORD: #{ENV['MEDELEMENT_PASSWORD'].present? ? '✓ установлено' : '✗ не установлено'}"
puts ""

begin
  puts "Вызов MedelementScraperService.fetch_all_specialists..."
  puts ""

  specialists = MedelementScraperService.fetch_all_specialists

  puts ""
  puts "=" * 80
  puts "Результат:"
  puts "  Найдено специалистов: #{specialists.size}"
  puts "=" * 80

  if specialists.any?
    puts ""
    puts "Первые 3 специалиста:"
    specialists.first(3).each_with_index do |s, i|
      puts "  #{i + 1}. #{s[:last_name]} #{s[:first_name]} - #{s[:email]}"
    end
  end
rescue StandardError => e
  puts ""
  puts "=" * 80
  puts "ОШИБКА:"
  puts "  Класс: #{e.class}"
  puts "  Сообщение: #{e.message}"
  puts "  Трейс:"
  puts e.backtrace.first(20).join("\n")
  puts "=" * 80
end
