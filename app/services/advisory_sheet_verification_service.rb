# frozen_string_literal: true

# Сервис для проверки консультативных листов
# Использует RAG для поиска релевантных протоколов и МКБ
class AdvisorySheetVerificationService
  RELEVANT_PROTOCOLS_LIMIT = 5
  RELEVANT_MKB_LIMIT = 10

  class << self
    # Проверка одного КЛ
    def verify(not_verified_sheet)
      # 1. Извлекаем ИИН врача ДО санитизации (чтобы потом привязать КЛ к врачу)
      doctor_iin = PersonalDataSanitizerService.extract_doctor_iin(not_verified_sheet.body)

      # 2. Санитизация персональных данных
      sanitized_content = PersonalDataSanitizerService.extract_medical_content(not_verified_sheet.body)

      return create_error_result(not_verified_sheet) if sanitized_content.blank?

      # 3. Извлечение ключевых полей (нужно для AI-анализа)
      extracted_fields = AdvisorySheetFieldExtractionService.extract(not_verified_sheet.body)

      # 4. Генерация эмбеддинга для поиска
      query_embedding = GeminiService.generate_embedding(sanitized_content)

      # 5. Поиск релевантных протоколов и МКБ
      relevant_protocols = find_relevant_protocols(query_embedding, sanitized_content)
      relevant_mkbs = find_relevant_mkbs(query_embedding, sanitized_content)

      # 6. Проверка через AI + детальный анализ полей (ОДИН запрос)
      verification = GeminiService.verify_advisory_sheet(
        sanitized_content,
        relevant_protocols,
        relevant_mkbs,
        extracted_fields  # Передаем извлеченные поля для анализа
      )

      # 7. Создание записи в verified_advisory_sheets с полями и оценками
      verified_sheet = create_verified_sheet(not_verified_sheet, verification, extracted_fields)

      # 8. Автоматическая привязка врача через парсинг medelement.com
      link_doctor_from_advisory_sheet(verified_sheet, not_verified_sheet.body)

      # 9. Автоматическая привязка врача по ИИН (если найден и не привязан ранее)
      link_doctor_by_iin(verified_sheet, doctor_iin) if doctor_iin.present?

      verified_sheet
    rescue StandardError => e
      Rails.logger.error("AdvisorySheetVerificationService: ошибка проверки КЛ ##{not_verified_sheet.recording}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      # Создаем запись с ошибкой вместо возврата nil
      create_error_result(not_verified_sheet)
    end

    # Массовая проверка всех непроверенных КЛ
    def verify_all_pending
      not_verified = NotVerifiedAdvisorySheet.all
      results = { success: 0, failed: 0 }

      not_verified.find_each do |sheet|
        result = verify(sheet)
        if result && result.persisted?
          results[:success] += 1
          sheet.destroy
        else
          results[:failed] += 1
        end
      end

      results
    end

    private

    def find_relevant_protocols(query_embedding, text_content)
      # Сначала ищем по векторному сходству
      vector_results = Protocol.search_similar(query_embedding, limit: RELEVANT_PROTOCOLS_LIMIT)

      # Дополнительно ищем по ключевым словам из текста
      keywords = extract_medical_keywords(text_content)
      text_results = keywords.flat_map do |keyword|
        Protocol.search_by_text(keyword).limit(2)
      end

      (vector_results + text_results).uniq.first(RELEVANT_PROTOCOLS_LIMIT)
    end

    def find_relevant_mkbs(query_embedding, text_content)
      # Извлекаем МКБ коды из текста КЛ
      mkb_codes_in_text = extract_mkb_codes(text_content)

      # Ищем эти коды в базе
      direct_mkbs = Mkb.where(code: mkb_codes_in_text)

      # Дополняем векторным поиском
      vector_results = Mkb.search_similar(query_embedding, limit: RELEVANT_MKB_LIMIT - direct_mkbs.count)

      (direct_mkbs.to_a + vector_results).uniq.first(RELEVANT_MKB_LIMIT)
    end

    def extract_mkb_codes(text)
      # Извлекаем коды МКБ из текста (формат: A00.0, M54.5, и т.д.)
      text.scan(/[A-Z]\d{2}(?:\.\d{1,2})?/i).map(&:upcase).uniq
    end

    def extract_medical_keywords(text)
      # Извлекаем медицинские термины для текстового поиска
      # Фильтруем короткие слова и общеупотребимые
      stop_words = %w[при для или что как это был была были есть]

      text.scan(/[А-Яа-яЁё]{5,}/)
          .map(&:downcase)
          .uniq
          .reject { |w| stop_words.include?(w) }
          .first(10)
    end

    def create_verified_sheet(not_verified, verification, extracted_fields)
      # Используем find_or_initialize_by чтобы избежать дубликатов
      verified = VerifiedAdvisorySheet.find_or_initialize_by(recording: not_verified.recording)
      verified.assign_attributes(
        body: not_verified.body,
        status: verification[:status],
        verification_result: verification[:result],
        recommendations: verification[:recommendations],
        auditor_id: not_verified.auditor_id,
        original_filename: not_verified.original_filename,
        verified_at: Time.current
      )
      verified.save!

      # Сохраняем ключевые поля с замечаниями от AI
      save_fields_with_analysis(verified, extracted_fields, verification[:field_analysis])

      verified
    end

    def create_error_result(not_verified)
      # Используем find_or_initialize_by чтобы избежать дубликатов
      verified = VerifiedAdvisorySheet.find_or_initialize_by(recording: not_verified.recording)
      verified.assign_attributes(
        body: not_verified.body,
        status: :purple,
        verification_result: "Не удалось извлечь медицинскую информацию для проверки",
        recommendations: "Требуется ручная проверка или загрузите КЛ повторно",
        auditor_id: not_verified.auditor_id,
        original_filename: not_verified.original_filename,
        verified_at: Time.current
      )
      verified.save!
      verified
    end

    # Сохраняет извлеченные поля + AI-замечания + оценки качества
    def save_fields_with_analysis(verified_sheet, extracted_fields, field_analysis)
      # Удаляем старые записи если есть
      verified_sheet.advisory_sheet_field&.destroy
      verified_sheet.advisory_sheet_score&.destroy

      # Создаем запись с извлеченными полями + замечаниями от AI
      field_attributes = {
        complaints: extracted_fields[:complaints],
        anamnesis_morbi: extracted_fields[:anamnesis_morbi],
        anamnesis_vitae: extracted_fields[:anamnesis_vitae],
        physical_examination: extracted_fields[:physical_examination],
        study_protocol: extracted_fields[:study_protocol],
        diagnoses: extracted_fields[:diagnoses],
        referrals: extracted_fields[:referrals],
        prescriptions: extracted_fields[:prescriptions],
        recommendations: extracted_fields[:recommendations],
        notes: extracted_fields[:notes]
      }

      # Добавляем замечания от AI (если есть)
      if field_analysis.present?
        field_attributes[:complaints_comment] = field_analysis["complaints"]&.dig(:comment)
        field_attributes[:anamnesis_morbi_comment] = field_analysis["anamnesis_morbi"]&.dig(:comment)
        field_attributes[:anamnesis_vitae_comment] = field_analysis["anamnesis_vitae"]&.dig(:comment)
        field_attributes[:physical_examination_comment] = field_analysis["physical_examination"]&.dig(:comment)
        field_attributes[:study_protocol_comment] = field_analysis["study_protocol"]&.dig(:comment)
        field_attributes[:diagnoses_comment] = field_analysis["diagnoses"]&.dig(:comment)
        field_attributes[:referrals_comment] = field_analysis["referrals"]&.dig(:comment)
        field_attributes[:prescriptions_comment] = field_analysis["prescriptions"]&.dig(:comment)
        field_attributes[:recommendations_comment] = field_analysis["recommendations"]&.dig(:comment)
        field_attributes[:notes_comment] = field_analysis["notes"]&.dig(:comment)
      end

      verified_sheet.create_advisory_sheet_field!(field_attributes)

      # Создаем оценки качества из AI-анализа
      if field_analysis.present?
        score_attributes = {
          complaints_score: field_analysis["complaints"]&.dig(:score) || 0.0,
          anamnesis_morbi_score: field_analysis["anamnesis_morbi"]&.dig(:score) || 0.0,
          anamnesis_vitae_score: field_analysis["anamnesis_vitae"]&.dig(:score) || 0.0,
          physical_examination_score: field_analysis["physical_examination"]&.dig(:score) || 0.0,
          study_protocol_score: field_analysis["study_protocol"]&.dig(:score) || 0.0,
          diagnoses_score: field_analysis["diagnoses"]&.dig(:score) || 0.0,
          referrals_score: field_analysis["referrals"]&.dig(:score) || 0.0,
          prescriptions_score: field_analysis["prescriptions"]&.dig(:score) || 0.0,
          recommendations_score: field_analysis["recommendations"]&.dig(:score) || 0.0,
          notes_score: field_analysis["notes"]&.dig(:score) || 0.0
        }

        # AdvisorySheetScore автоматически рассчитает total_score и percentage через before_save
        verified_sheet.create_advisory_sheet_score!(score_attributes)
      end
    rescue StandardError => e
      Rails.logger.error("AdvisorySheetVerificationService: ошибка сохранения полей и оценок: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      # Не прерываем основной процесс верификации, просто логируем ошибку
    end

    # Автоматическая привязка врача через парсинг medelement.com
    def link_doctor_from_advisory_sheet(verified_sheet, content)
      # 1. Извлекаем ФИО врача из КЛ
      doctor_name = DoctorDataExtractorService.extract(content)

      return if doctor_name[:full_name].blank?

      Rails.logger.info("Извлечено ФИО врача из КЛ: #{doctor_name[:full_name]}")

      # 2. Ищем врача на medelement.com
      medelement_data = MedelementScraperService.find_doctor(doctor_name)

      # 3. Подготавливаем данные для создания аккаунта
      doctor_data = if medelement_data.present?
        Rails.logger.info("Врач найден на medelement.com: #{medelement_data[:email]}")
        medelement_data
      else
        Rails.logger.info("Врач не найден на medelement.com, будет создан с автогенерированным email")
        doctor_name # Только ФИО, email сгенерируется автоматически
      end

      # 4. Находим или создаем аккаунт врача
      doctor = DoctorAccountService.find_or_create(doctor_data)

      # 5. Привязываем к консультативному листу
      if doctor.present?
        DoctorAccountService.link_to_advisory_sheet(doctor, verified_sheet)
        Rails.logger.info("КЛ ##{verified_sheet.recording} привязан к врачу: #{doctor.full_name} (#{doctor.email})")
      end
    rescue StandardError => e
      Rails.logger.error("Ошибка привязки врача к КЛ: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      # Не прерываем процесс верификации, просто логируем ошибку
    end

    # Привязка врача по ИИН (если такая логика потребуется)
    def link_doctor_by_iin(verified_sheet, doctor_iin)
      return if doctor_iin.blank?

      # Ищем врача по doctor_identifier (если используется ИИН как идентификатор)
      doctor = Doctor.find_by(doctor_identifier: doctor_iin)

      if doctor.present? && !verified_sheet.doctors.include?(doctor)
        DoctorAccountService.link_to_advisory_sheet(doctor, verified_sheet)
        Rails.logger.info("КЛ ##{verified_sheet.recording} привязан к врачу по ИИН: #{doctor.full_name}")
      end
    rescue StandardError => e
      Rails.logger.error("Ошибка привязки врача по ИИН: #{e.message}")
      # Не прерываем процесс
    end
  end
end
