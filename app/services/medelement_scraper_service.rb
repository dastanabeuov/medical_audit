# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "nokogiri"

# Сервис для парсинга данных врачей с сайта medelement.com
class MedelementScraperService
  CLINIC_URLS = [
    "https://co.medelement.com/ref_companies/view/NTg4ODUxNjAxNjU3MTc1MjU3/fDh8",
    "https://co.medelement.com/ref_companies/view/NTIwODU4NTkxNzE3MDczODQz/fDh8",
    "https://co.medelement.com/ref_companies/view/MTYzMTk3MDE2MzA5MjMyMTg%253D/fDh8"
  ].freeze

  LOGIN_URL = "https://co.medelement.com/login"
  BASE_URL = "https://co.medelement.com"

  class << self
    # Поиск врача по ФИО на всех клиниках
    # @param doctor_name [Hash] - { first_name:, last_name:, second_name: }
    # @return [Hash, nil] - данные врача или nil если не найден
    def find_doctor(doctor_name)
      return nil if doctor_name[:last_name].blank? || doctor_name[:first_name].blank?

      session = authenticate

      return nil unless session

      CLINIC_URLS.each do |clinic_url|
        doctor_data = search_doctor_in_clinic(session, clinic_url, doctor_name)
        return doctor_data if doctor_data.present?
      end

      nil
    rescue StandardError => e
      Rails.logger.error("MedelementScraperService error: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      nil
    end

    private

    # Авторизация на сайте
    def authenticate
      login = ENV["MEDELEMENT_LOGIN"]
      password = ENV["MEDELEMENT_PASSWORD"]

      unless login.present? && password.present?
        Rails.logger.error("MEDELEMENT_LOGIN or MEDELEMENT_PASSWORD not set in ENV")
        return nil
      end

      uri = URI(LOGIN_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Получаем форму входа для извлечения CSRF токена
      get_request = Net::HTTP::Get.new(uri)
      get_response = http.request(get_request)

      # Парсим CSRF токен из формы
      doc = Nokogiri::HTML(get_response.body)
      csrf_token = doc.css('input[name="authenticity_token"]').first&.attr("value")

      # Отправляем POST запрос с учетными данными
      post_request = Net::HTTP::Post.new(uri)
      post_request.set_form_data({
        "authenticity_token" => csrf_token,
        "email" => login,
        "password" => password
      })

      # Копируем cookies из GET запроса
      cookies = get_response.get_fields("set-cookie")
      post_request["Cookie"] = cookies.join("; ") if cookies

      post_response = http.request(post_request)

      # Проверяем успешность авторизации
      if post_response.is_a?(Net::HTTPRedirection) || post_response.is_a?(Net::HTTPSuccess)
        # Собираем все cookies для сессии
        all_cookies = (cookies || []) + (post_response.get_fields("set-cookie") || [])
        session_cookie = all_cookies.map { |c| c.split(";").first }.join("; ")

        {
          cookie: session_cookie,
          http: http
        }
      else
        Rails.logger.error("Failed to authenticate on medelement.com: #{post_response.code}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Authentication error: #{e.message}")
      nil
    end

    # Поиск врача в конкретной клинике
    def search_doctor_in_clinic(session, clinic_url, doctor_name)
      uri = URI(clinic_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Cookie"] = session[:cookie]

      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      # Парсим HTML страницы клиники
      doc = Nokogiri::HTML(response.body)

      # Ищем врача по ФИО
      # Предполагаем, что врачи перечислены в таблице или списке
      doctor_element = find_doctor_element(doc, doctor_name)

      return nil unless doctor_element

      # Извлекаем данные врача
      extract_doctor_data(doctor_element, doctor_name)
    rescue StandardError => e
      Rails.logger.error("Error searching doctor in clinic #{clinic_url}: #{e.message}")
      nil
    end

    # Поиск элемента врача на странице
    def find_doctor_element(doc, doctor_name)
      # Пытаемся найти по полному имени
      full_name_variants = [
        "#{doctor_name[:last_name]} #{doctor_name[:first_name]} #{doctor_name[:second_name]}".strip,
        "#{doctor_name[:last_name]} #{doctor_name[:first_name]}".strip,
        "#{doctor_name[:first_name]} #{doctor_name[:last_name]}".strip
      ]

      # Ищем в различных возможных селекторах
      selectors = [
        ".doctor-card",
        ".staff-member",
        "tr.doctor-row",
        ".employee-item",
        "div[data-doctor]"
      ]

      selectors.each do |selector|
        doc.css(selector).each do |element|
          text = element.text.strip
          return element if full_name_variants.any? { |name| text.include?(name) }
        end
      end

      # Если не нашли точное совпадение, ищем по фамилии и имени отдельно
      doc.search("*").find do |element|
        text = element.text.strip
        text.include?(doctor_name[:last_name]) && text.include?(doctor_name[:first_name])
      end
    end

    # Извлечение данных врача из элемента
    def extract_doctor_data(element, doctor_name)
      # Ищем email в тексте элемента или в атрибутах
      email = extract_email(element)

      # Ищем специализацию
      specialization = extract_specialization(element)

      # Ищем отделение/кабинет
      department = extract_department(element)

      {
        email: email,
        first_name: doctor_name[:first_name],
        last_name: doctor_name[:last_name],
        second_name: doctor_name[:second_name],
        specialization: specialization,
        department: department,
        clinic: extract_clinic_name(element),
        found_on_medelement: true
      }
    end

    # Извлечение email
    def extract_email(element)
      # Паттерн для поиска email
      email_pattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/

      # Ищем в тексте
      text = element.text
      match = text.match(email_pattern)
      return match[0] if match

      # Ищем в атрибутах ссылок mailto:
      email_link = element.css('a[href^="mailto:"]').first
      return email_link["href"].gsub("mailto:", "") if email_link

      # Ищем в data-атрибутах
      email_attr = element["data-email"] || element.css("[data-email]").first&.[]("data-email")
      return email_attr if email_attr.present?

      nil
    end

    # Извлечение специализации
    def extract_specialization(element)
      # Ключевые слова для поиска специализации
      keywords = %w[специализация специальность должность]

      text = element.text.downcase
      keywords.each do |keyword|
        if text.include?(keyword)
          # Извлекаем строку после ключевого слова
          match = text.match(/#{keyword}[\s:]+([^\n,]+)/i)
          return match[1].strip.capitalize if match
        end
      end

      nil
    end

    # Извлечение отделения
    def extract_department(element)
      # Ключевые слова для отделения/кабинета
      keywords = %w[отделение кабинет департамент]

      text = element.text.downcase
      keywords.each do |keyword|
        if text.include?(keyword)
          match = text.match(/#{keyword}[\s:]+([^\n,]+)/i)
          return match[1].strip.capitalize if match
        end
      end

      nil
    end

    # Извлечение названия клиники
    def extract_clinic_name(element)
      # Пытаемся найти название клиники на странице
      doc = element.document

      # Ищем в заголовке страницы
      clinic_name = doc.css("h1.clinic-name, .company-name, h1").first&.text&.strip

      clinic_name.presence || "Неизвестная клиника"
    end
  end
end
