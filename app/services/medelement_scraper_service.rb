# frozen_string_literal: true

require "selenium-webdriver"
require "nokogiri"

# Сервис для парсинга данных врачей с сайта medelement.com
# Использует Selenium WebDriver для браузерной автоматизации
class MedelementScraperService
  CLINIC_URLS = [
    "https://co.medelement.com/ref_companies/view/NTg4ODUxNjAxNjU3MTc1MjU3/fDh8",
    "https://co.medelement.com/ref_companies/view/MTYzMTk3MDE2MzA5MjMyMTg%253D/fDh8",
    "https://co.medelement.com/ref_companies/view/NTIwODU4NTkxNzE3MDczODQz/fDh8"
  ].freeze

  LOGIN_URL = "https://login.medelement.com/"
  BASE_URL = "https://co.medelement.com"

  # Таймауты для ожидания элементов (в секундах)
  WAIT_TIMEOUT = 30
  PAGE_LOAD_TIMEOUT = 60

  class << self
    # Поиск врача по ФИО на всех клиниках
    # @param doctor_name [Hash] - { first_name:, last_name:, second_name: }
    # @return [Hash, nil] - данные врача или nil если не найден
    def find_doctor(doctor_name)
      return nil if doctor_name[:last_name].blank? || doctor_name[:first_name].blank?

      driver = nil

      begin
        driver = create_driver
        authenticate_with_browser(driver)

        CLINIC_URLS.each do |clinic_url|
          doctor_data = search_doctor_in_clinic_with_browser(driver, clinic_url, doctor_name)
          return doctor_data if doctor_data.present?
        end

        nil
      rescue StandardError => e
        Rails.logger.error("MedelementScraperService error: #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n"))
        nil
      ensure
        driver&.quit
      end
    end

    # Получение списка всех специалистов из всех клиник
    # @return [Array<Hash>] - массив хешей с данными специалистов
    def fetch_all_specialists
      Rails.logger.info("=" * 80)
      Rails.logger.info("MedelementScraperService: Начало импорта специалистов")
      Rails.logger.info("=" * 80)

      driver = nil
      all_specialists = []

      begin
        Rails.logger.info("Шаг 1: Создание драйвера Selenium...")
        driver = create_driver
        Rails.logger.info("✓ Драйвер создан успешно")

        Rails.logger.info("Шаг 2: Авторизация на medelement.com...")
        authenticate_with_browser(driver)
        Rails.logger.info("✓ Авторизация прошла успешно")

        Rails.logger.info("Шаг 3: Парсинг клиник (всего: #{CLINIC_URLS.size})")
        CLINIC_URLS.each_with_index do |clinic_url, index|
          Rails.logger.info("")
          Rails.logger.info("Клиника #{index + 1}/#{CLINIC_URLS.size}")
          specialists = parse_specialists_from_clinic(driver, clinic_url)
          all_specialists.concat(specialists)
          Rails.logger.info("  Найдено специалистов в клинике: #{specialists.size}")
        end

        Rails.logger.info("")
        Rails.logger.info("=" * 80)
        Rails.logger.info("Парсинг завершен. Всего найдено специалистов: #{all_specialists.size}")
        Rails.logger.info("=" * 80)
        all_specialists
      rescue StandardError => e
        Rails.logger.error("=" * 80)
        Rails.logger.error("ОШИБКА при получении списка специалистов:")
        Rails.logger.error("  Тип: #{e.class}")
        Rails.logger.error("  Сообщение: #{e.message}")
        Rails.logger.error("  Трейс:")
        Rails.logger.error(e.backtrace.first(15).join("\n"))
        Rails.logger.error("=" * 80)
        all_specialists
      ensure
        if driver
          Rails.logger.info("Закрытие браузера...")
          driver.quit
          Rails.logger.info("✓ Браузер закрыт")
        end
      end
    end

    private

    # Создание драйвера Selenium с настройками
    def create_driver
      # Указываем путь к настоящему ChromeDriver binary (не snap wrapper)
      chromedriver_path = Rails.root.join("bin", "chromedriver").to_s
      Selenium::WebDriver::Chrome::Service.driver_path = chromedriver_path

      options = Selenium::WebDriver::Chrome::Options.new

      # Используем google-chrome-stable
      options.binary = "/usr/bin/google-chrome-stable"

      # Headless режим
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--disable-software-rasterizer")
      options.add_argument("--window-size=1920,1080")

      # User-agent
      options.add_argument("user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

      Rails.logger.info("  Создание Chrome WebDriver")
      Rails.logger.info("  - ChromeDriver: #{chromedriver_path}")
      Rails.logger.info("  - Chrome binary: /usr/bin/google-chrome-stable")

      driver = Selenium::WebDriver.for :chrome, options: options
      driver.manage.timeouts.implicit_wait = 5
      driver.manage.timeouts.page_load = PAGE_LOAD_TIMEOUT

      Rails.logger.info("  ✓ WebDriver успешно создан")
      driver
    end

    # Авторизация через браузер
    def authenticate_with_browser(driver)
      login = ENV["MEDELEMENT_LOGIN"]
      password = ENV["MEDELEMENT_PASSWORD"]

      unless login.present? && password.present?
        raise "MEDELEMENT_LOGIN or MEDELEMENT_PASSWORD not set in ENV"
      end

      Rails.logger.info("Переход на страницу авторизации: #{LOGIN_URL}")
      driver.navigate.to LOGIN_URL

      # Ждем загрузки формы входа
      wait = Selenium::WebDriver::Wait.new(timeout: WAIT_TIMEOUT)

      # Ищем поля ввода email и password
      email_field = wait.until do
        driver.find_element(css: 'input[type="email"], input[name="email"], input#email')
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      password_field = driver.find_element(css: 'input[type="password"], input[name="password"], input#password')

      Rails.logger.info("Заполнение формы авторизации")
      email_field.send_keys(login)
      password_field.send_keys(password)

      # Ищем и нажимаем кнопку входа (используем XPath для текста "Войти")
      submit_button = driver.find_element(css: 'button[type="submit"], input[type="submit"]') rescue
                      driver.find_element(xpath: '//button[contains(text(), "Войти")] | //input[@value="Войти"]')
      submit_button.click

      # Ждем перенаправления после успешной авторизации
      wait.until do
        current_url = driver.current_url
        !current_url.include?("login.medelement.com")
      end

      Rails.logger.info("Успешная авторизация на medelement.com")
      sleep(2) # Дополнительная пауза для стабилизации сессии
    rescue StandardError => e
      Rails.logger.error("Ошибка авторизации: #{e.message}")
      raise
    end

    # Поиск врача в конкретной клинике через браузер
    def search_doctor_in_clinic_with_browser(driver, clinic_url, doctor_name)
      Rails.logger.info("Поиск врача в клинике: #{clinic_url}")
      driver.navigate.to clinic_url

      # Ждем загрузки страницы
      wait = Selenium::WebDriver::Wait.new(timeout: WAIT_TIMEOUT)
      wait.until { driver.execute_script("return document.readyState") == "complete" }

      sleep(2) # Дополнительная пауза для загрузки динамического контента

      # Получаем HTML страницы
      page_source = driver.page_source
      doc = Nokogiri::HTML(page_source)

      # Ищем врача по ФИО
      doctor_element = find_doctor_element(doc, doctor_name)

      return nil unless doctor_element

      # Извлекаем данные врача
      extract_doctor_data(doctor_element, doctor_name, doc)
    rescue StandardError => e
      Rails.logger.error("Ошибка поиска врача в клинике #{clinic_url}: #{e.message}")
      nil
    end

    # Парсинг всех специалистов из клиники
    def parse_specialists_from_clinic(driver, clinic_url)
      Rails.logger.info("  Переход на страницу клиники: #{clinic_url}")
      driver.navigate.to clinic_url

      # Ждем загрузки страницы
      wait = Selenium::WebDriver::Wait.new(timeout: WAIT_TIMEOUT)
      wait.until { driver.execute_script("return document.readyState") == "complete" }

      sleep(2) # Пауза для загрузки

      # ВАЖНО: Нужно кликнуть на вкладку "Специалисты" чтобы загрузить данные через AJAX
      Rails.logger.info("  Клик на вкладку 'Специалисты' для загрузки данных...")
      begin
        specialists_tab = wait.until do
          driver.find_element(xpath: '//li[@tab-eng-name="LIST_SPECIALISTS"]//a | //li[contains(text(), "Специалисты")]//a')
        end
        specialists_tab.click
        Rails.logger.info("  ✓ Вкладка 'Специалисты' активирована, ожидаем загрузки данных...")

        # Явное ожидание загрузки данных в таблице (до 30 секунд)
        data_loaded = wait.until do
          # Проверяем, что загрузчик AJAX исчез или скрыт
          ajax_loader = driver.find_elements(css: "#ajaxLoad[style*=\"display: block\"]")
          ajax_loader_hidden = ajax_loader.empty?

          # Проверяем, что в таблице появились данные
          table = driver.find_elements(css: "#table-specialists")
          has_table = table.any?

          if has_table
            record_count = table.first.attribute("data-recordcount").to_s
            has_data = !record_count.start_with?("0")

            Rails.logger.debug("  Проверка загрузки: loader_hidden=#{ajax_loader_hidden}, has_table=#{has_table}, record_count=#{record_count}")

            # Данные загружены если загрузчик скрыт И таблица не пустая
            ajax_loader_hidden && has_data
          else
            false
          end
        rescue Selenium::WebDriver::Error::TimeoutError
          # Если timeout, возвращаем false чтобы wait продолжил ожидание
          false
        end

        if data_loaded
          Rails.logger.info("  ✓ Данные специалистов успешно загружены через AJAX")
          sleep(1) # Небольшая пауза для стабилизации
        else
          Rails.logger.warn("  ⚠ Данные не загрузились за 30 секунд, пробуем парсить как есть")
        end

      rescue Selenium::WebDriver::Error::NoSuchElementError
        Rails.logger.warn("  ⚠ Вкладка 'Специалисты' не найдена, пробуем парсить как есть")
      rescue Selenium::WebDriver::Error::TimeoutError
        Rails.logger.warn("  ⚠ Timeout при ожидании загрузки данных, пробуем парсить как есть")
      end

      Rails.logger.info("  Страница загружена, начинаем парсинг...")

      # Получаем HTML страницы
      page_source = driver.page_source
      doc = Nokogiri::HTML(page_source)

      # DEBUG: Сохраняем HTML для анализа (только в development)
      if Rails.env.development?
        html_file = Rails.root.join("tmp", "clinic_page_#{Time.now.to_i}.html")
        File.write(html_file, page_source)
        Rails.logger.info("  DEBUG: HTML сохранен в #{html_file}")
      end

      # Извлекаем название клиники
      clinic_name = extract_clinic_name(doc)
      Rails.logger.info("  Название клиники: #{clinic_name}")

      # Парсим всех специалистов
      specialists = []

      # Новый подход: ищем группы специалистов (group rows)
      # Структура: строка группы + строка с деталями
      group_rows = doc.css('tr[id^="tr_group_type"]')
      Rails.logger.info("  Найдено группVрачей: #{group_rows.size}")

      group_rows.each_with_index do |group_row, index|
        Rails.logger.debug("  [#{index + 1}/#{group_rows.size}] Обработка группы")

        # Извлекаем данные из строки группы
        group_data = parse_group_row(group_row)
        next unless group_data

        # Ищем следующую строку с деталями (Тип кабинета, Название кабинета)
        next_row = group_row.next_element
        if next_row && next_row.name == "tr"
          detail_data = parse_detail_row(next_row)
          group_data.merge!(detail_data) if detail_data
        end

        # Добавляем название клиники
        group_data[:clinic] = clinic_name
        group_data[:found_on_medelement] = true

        specialists << group_data
        Rails.logger.info("  ✓ Специалист добавлен: #{group_data[:last_name]} #{group_data[:first_name]} (#{group_data[:email]})")
      end

      Rails.logger.info("  Итого специалистов извлечено из клиники: #{specialists.size}")
      specialists
    rescue StandardError => e
      Rails.logger.error("Ошибка парсинга специалистов из клиники #{clinic_url}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      []
    end

    # Парсинг строки группы (ФИО, email, Тип профиля)
    # <span field-type="text">ФИО <span style="color: grey;"> - email</span></span>
    # <span style="clear:both;">Тип профиля: Врач+стационар</span>
    def parse_group_row(row)
      # Ищем span с field-type="text" для ФИО и email
      name_span = row.css('span[field-number="5"][field-type="text"]').first
      return nil unless name_span

      # Извлекаем email из серого span
      email_span = name_span.css('span[style*="grey"], span[style*="gray"]').first
      email = nil
      if email_span
        email_text = email_span.text.strip.sub(/^\s*-\s*/, "")
        email = email_text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)&.[](0)
      end

      return nil if email.blank?

      # Извлекаем ФИО (текст до email)
      full_text = name_span.text.strip
      full_name = full_text.split("-").first.strip
      name_parts = parse_full_name(full_name)

      return nil if name_parts[:last_name].blank? || name_parts[:first_name].blank?

      # Извлекаем Тип профиля
      profile_type_span = row.css('span[style*="clear"]').find { |s| s.text.include?("Тип профиля:") }
      profile_type = nil
      if profile_type_span
        profile_type = profile_type_span.text.sub(/Тип профиля:\s*/i, "").strip
      end

      {
        email: email,
        first_name: name_parts[:first_name],
        last_name: name_parts[:last_name],
        second_name: name_parts[:second_name],
        specialization: profile_type || "Не указано"
      }
    rescue StandardError => e
      Rails.logger.warn("Ошибка парсинга группы специалиста: #{e.message}")
      nil
    end

    # Парсинг строки деталей (Тип кабинета, Название кабинета)
    # <td column-number="2">Тип кабинета: КТ</td>
    # <td column-number="3">Название кабинета: <span>...</span></td>
    def parse_detail_row(row)
      result = {}

      # Извлекаем Тип кабинета
      type_td = row.css('td[column-number="2"]').first
      if type_td
        type_text = type_td.text.strip
        if type_text.include?("Тип кабинета:")
          result[:cabinet_type] = type_text.sub(/Тип кабинета:\s*/i, "").strip
        end
      end

      # Извлекаем Название кабинета (department)
      name_td = row.css('td[column-number="3"]').first
      if name_td
        # Ищем span с field-type="text"
        name_span = name_td.css('span[field-type="text"]').first
        if name_span
          result[:department] = name_span.text.strip
        else
          # Fallback: весь текст после "Название кабинета:"
          name_text = name_td.text.strip
          if name_text.include?("Название кабинета:")
            result[:department] = name_text.sub(/Название кабинета:\s*/i, "").strip
          end
        end
      end

      result
    rescue StandardError => e
      Rails.logger.warn("Ошибка парсинга деталей специалиста: #{e.message}")
      {}
    end

    # Парсинг данных одного специалиста из элемента (старый метод, оставлен для совместимости)
    def parse_specialist_element(element, clinic_name)
      text = element.text.strip
      return nil if text.blank?

      # Извлекаем email
      email = extract_email(element)
      return nil if email.blank?

      # Парсим ФИО (до " - email" или до серого span)
      full_name = text.split("-").first.strip
      name_parts = parse_full_name(full_name)

      return nil if name_parts[:last_name].blank? || name_parts[:first_name].blank?

      {
        email: email,
        first_name: name_parts[:first_name],
        last_name: name_parts[:last_name],
        second_name: name_parts[:second_name],
        clinic: clinic_name,
        found_on_medelement: true
      }
    rescue StandardError => e
      Rails.logger.warn("Ошибка парсинга специалиста: #{e.message}")
      nil
    end

    # Парсинг полного имени на составляющие
    def parse_full_name(full_name)
      parts = full_name.strip.split(/\s+/)

      case parts.size
      when 3
        # Фамилия Имя Отчество
        { last_name: parts[0], first_name: parts[1], second_name: parts[2] }
      when 2
        # Фамилия Имя
        { last_name: parts[0], first_name: parts[1], second_name: nil }
      when 1
        # Только фамилия (редкий случай)
        { last_name: parts[0], first_name: nil, second_name: nil }
      else
        # Более 3 частей - берем первые 3
        { last_name: parts[0], first_name: parts[1], second_name: parts[2..-1].join(" ") }
      end
    end

    # Поиск элемента врача на странице
    def find_doctor_element(doc, doctor_name)
      last_name = doctor_name[:last_name]
      first_name = doctor_name[:first_name]
      second_name = doctor_name[:second_name]

      # Формируем варианты поиска в зависимости от наличия отчества
      full_name_variants = []

      # Вариант 1: Полное имя (если есть отчество)
      if second_name.present?
        full_name_variants << "#{last_name} #{first_name} #{second_name}".strip
      end

      # Вариант 2: БЕЗ отчества (фамилия имя)
      full_name_variants << "#{last_name} #{first_name}".strip

      # Вариант 3: В обратном порядке (имя фамилия)
      full_name_variants << "#{first_name} #{last_name}".strip

      # Вариант 4: В обратном порядке с отчеством (если есть)
      if second_name.present?
        full_name_variants << "#{first_name} #{last_name} #{second_name}".strip
      end

      Rails.logger.debug("Поиск врача по вариантам: #{full_name_variants.inspect}")

      # СТРАТЕГИЯ 1: Точное совпадение по одному из вариантов
      doc.css('span[field-type="text"]').each do |element|
        text = element.text.strip.downcase

        # Проверяем каждый вариант (регистронезависимо)
        full_name_variants.each do |variant|
          return element if text.include?(variant.downcase)
        end
      end

      # СТРАТЕГИЯ 2: Поиск по фамилии И имени (независимо от отчества)
      Rails.logger.debug("Точное совпадение не найдено, ищем по фамилии+имени")
      doc.css('span[field-type="text"]').find do |element|
        text = element.text.strip.downcase
        text.include?(last_name.downcase) && text.include?(first_name.downcase)
      end
    end

    # Извлечение данных врача из элемента
    def extract_doctor_data(element, doctor_name, doc)
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
        clinic: extract_clinic_name(doc),
        found_on_medelement: true
      }
    end

    # Извлечение email
    def extract_email(element)
      # Паттерн для поиска email
      email_pattern = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/

      # 1. Ищем в серых span-ах (основная структура medelement)
      grey_spans = element.css('span[style*="grey"], span[style*="gray"]')
      grey_spans.each do |span|
        text = span.text.strip
        # Убираем префикс " - " если есть
        text = text.sub(/^\s*-\s*/, "")
        match = text.match(email_pattern)
        return match[0] if match
      end

      # 2. Ищем в span с field-type="text"
      field_spans = element.css('span[field-type="text"]')
      field_spans.each do |span|
        match = span.text.match(email_pattern)
        return match[0] if match
      end

      # 3. Ищем в общем тексте элемента
      text = element.text
      match = text.match(email_pattern)
      return match[0] if match

      # 4. Ищем в атрибутах ссылок mailto:
      email_link = element.css('a[href^="mailto:"]').first
      return email_link["href"].gsub("mailto:", "") if email_link

      # 5. Ищем в data-атрибутах
      email_attr = element["data-email"] || element.css("[data-email]").first&.[]("data-email")
      return email_attr if email_attr.present?

      nil
    end

    # Извлечение специализации
    def extract_specialization(element)
      # Ключевые слова для поиска специализации
      keywords = [ "Название кабинета:",
                  "специализация",
                  "специальность",
                  "должность" ]

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
      keywords = [ "Тип кабинета:",
                  "отделение",
                  "департамент" ]

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
    def extract_clinic_name(doc)
      # Ищем в специальном элементе header-panel-description-2
      clinic_element = doc.css("#header-panel-description-2").first
      if clinic_element
        # Извлекаем из атрибута title
        title_text = clinic_element["title"]
        if title_text.present?
          # Убираем префикс "Специалисты -> "
          clinic_name = title_text.sub(/^Специалисты\s*->\s*/, "").strip
          return clinic_name if clinic_name.present?
        end
      end

      # Запасной вариант: ищем в заголовке страницы
      clinic_name = doc.css("h1.clinic-name, .company-name, h1").first&.text&.strip

      clinic_name.presence || "Неизвестная клиника"
    end
  end
end
