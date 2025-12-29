#!/usr/bin/env ruby
# frozen_string_literal: true

# Скрипт для тестирования AJAX endpoint medelement.com
# Использование:
#   ruby test_ajax_endpoint.rb

require "net/http"
require "uri"
require "json"
require "dotenv/load"

# ============================================================================
# НАСТРОЙКИ - ЗАПОЛНИТЕ ПОСЛЕ НАХОЖДЕНИЯ ENDPOINT
# ============================================================================

# URL endpoint (из найденного cURL)
ENDPOINT_URL = "https://co.medelement.com/ref_companies/view/NTg4ODUxNjAxNjU3MTc1MjU3/fDh8"

# Метод запроса (POST из cURL)
REQUEST_METHOD = "POST"

# Параметры запроса (пустое тело - content-length: 0)
REQUEST_PARAMS = {}

# Дополнительные заголовки (из cURL)
ADDITIONAL_HEADERS = {
  "X-Requested-With" => "XMLHttpRequest",
  "Accept" => "*/*",
  "Referer" => "https://co.medelement.com/ref_companies/view/NTg4ODUxNjAxNjU3MTc1MjU3/fDh8"
}


# ============================================================================
# КОД
# ============================================================================

def create_http_client(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30
  http
end

def authenticate
  login = ENV["MEDELEMENT_LOGIN"]
  password = ENV["MEDELEMENT_PASSWORD"]

  unless login && password
    puts "❌ ОШИБКА: MEDELEMENT_LOGIN или MEDELEMENT_PASSWORD не установлены в .env"
    exit 1
  end

  login_uri = URI("https://login.medelement.com/")

  puts "🔐 Авторизация на medelement.com..."

  http = create_http_client(login_uri)

  # GET запрос для получения CSRF токена
  get_request = Net::HTTP::Get.new(login_uri)
  get_response = http.request(get_request)

  # Извлекаем CSRF token
  csrf_token = get_response.body.match(/name="authenticity_token"[^>]*value="([^"]+)"/i)&.[](1)

  # Собираем cookies
  initial_cookies = (get_response.get_fields("set-cookie") || []).map { |c| c.split(";").first }.join("; ")

  # POST запрос с авторизацией
  post_request = Net::HTTP::Post.new(login_uri)
  post_request["Cookie"] = initial_cookies
  post_request.set_form_data({
    "authenticity_token" => csrf_token,
    "email" => login,
    "password" => password
  })

  post_response = http.request(post_request)

  # Объединяем cookies
  all_cookies = [ initial_cookies, (post_response.get_fields("set-cookie") || []).map { |c| c.split(";").first }.join("; ") ].join("; ")

  # Нормализуем cookies
  cookie_hash = {}
  all_cookies.split(";").map(&:strip).each do |cookie|
    next if cookie.empty?
    key, value = cookie.split("=", 2)
    cookie_hash[key.strip] = value.to_s.strip if key
  end
  session_cookie = cookie_hash.map { |k, v| "#{k}=#{v}" }.join("; ")

  puts "✓ Авторизация успешна"
  puts "✓ Cookies: #{session_cookie[0..100]}..."
  puts

  session_cookie
end

def test_endpoint(session_cookie)
  puts "=" * 80
  puts "ТЕСТИРОВАНИЕ AJAX ENDPOINT"
  puts "=" * 80
  puts "URL: #{ENDPOINT_URL}"
  puts "Method: #{REQUEST_METHOD}"
  puts "Params: #{REQUEST_PARAMS.inspect}"
  puts

  uri = if REQUEST_METHOD.upcase == "GET" && REQUEST_PARAMS.any?
    query_string = URI.encode_www_form(REQUEST_PARAMS)
    URI("#{ENDPOINT_URL}?#{query_string}")
  else
    URI(ENDPOINT_URL)
  end

  http = create_http_client(uri)

  request = if REQUEST_METHOD.upcase == "POST"
    req = Net::HTTP::Post.new(uri)
    # Устанавливаем Content-Type только если есть тело запроса
    if REQUEST_PARAMS.any?
      req["Content-Type"] = "application/json"
      req.body = REQUEST_PARAMS.to_json
    else
      req["Content-Length"] = "0"
    end
    req
  else
    Net::HTTP::Get.new(uri)
  end

  # Устанавливаем заголовки
  request["Cookie"] = session_cookie
  request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
  request["Accept"] = "application/json, text/javascript, */*; q=0.01"

  ADDITIONAL_HEADERS.each do |key, value|
    request[key] = value
  end

  puts "📡 Отправка запроса..."
  response = http.request(request)

  puts
  puts "=" * 80
  puts "ОТВЕТ"
  puts "=" * 80
  puts "Status Code: #{response.code} #{response.message}"
  puts "Content-Type: #{response['content-type']}"
  puts "Content-Length: #{response.body.size} bytes"
  puts

  # Пытаемся распарсить JSON
  begin
    # Обработка gzip
    body = if response["content-encoding"] == "gzip"
      require "zlib"
      require "stringio"
      Zlib::GzipReader.new(StringIO.new(response.body)).read
    else
      response.body
    end

    if response["content-type"]&.include?("json")
      json_data = JSON.parse(body)
      puts "✓ Валидный JSON"
      puts
      puts "JSON структура:"
      puts JSON.pretty_generate(json_data)
      puts
      puts "=" * 80

      # Анализ структуры
      if json_data.is_a?(Hash)
        puts "Ключи верхнего уровня: #{json_data.keys.join(', ')}"

        # Ищем массив специалистов
        specialists_key = json_data.keys.find { |k| k.to_s.downcase.include?("specialist") || k.to_s.downcase.include?("doctor") || k.to_s.downcase.include?("list") }

        if specialists_key && json_data[specialists_key].is_a?(Array)
          puts "Найден массив специалистов: '#{specialists_key}'"
          puts "Количество элементов: #{json_data[specialists_key].size}"

          if json_data[specialists_key].any?
            puts
            puts "Первый элемент:"
            puts JSON.pretty_generate(json_data[specialists_key].first)
          end
        end
      elsif json_data.is_a?(Array)
        puts "Массив из #{json_data.size} элементов"
        if json_data.any?
          puts
          puts "Первый элемент:"
          puts JSON.pretty_generate(json_data.first)
        end
      end
    else
      puts "⚠️  Ответ не JSON"
      puts "Первые 500 символов:"
      puts body[0..500]
    end
  rescue JSON::ParserError => e
    puts "❌ Ошибка парсинга JSON: #{e.message}"
    puts "Первые 500 символов ответа:"
    puts response.body[0..500]
  end

  puts "=" * 80
end

# ============================================================================
# ЗАПУСК
# ============================================================================

begin
  # Проверяем, что endpoint настроен
  if ENDPOINT_URL.include?("ajax/specialists") && !REQUEST_PARAMS.any?
    puts "⚠️  ВНИМАНИЕ: Похоже, endpoint еще не настроен"
    puts "Пожалуйста, отредактируйте test_ajax_endpoint.rb и укажите:"
    puts "  - ENDPOINT_URL (найденный URL)"
    puts "  - REQUEST_METHOD (GET или POST)"
    puts "  - REQUEST_PARAMS (параметры запроса)"
    puts "  - ADDITIONAL_HEADERS (если нужны)"
    puts
    puts "См. инструкцию в FIND_AJAX_ENDPOINT.md"
    exit 0
  end

  session_cookie = authenticate
  test_endpoint(session_cookie)

  puts
  puts "✅ Тест завершен!"
rescue StandardError => e
  puts
  puts "=" * 80
  puts "❌ ОШИБКА"
  puts "=" * 80
  puts "#{e.class}: #{e.message}"
  puts
  puts "Traceback:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
