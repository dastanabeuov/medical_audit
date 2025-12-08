class ConsultationSheetsController < ApplicationController
  def index
    @sheets = ConsultationSheet
      .includes(:audit_batch)
      .order(created_at: :desc)
      .page(params[:page])

    # Фильтрация по риск-уровню
    if params[:risk_level].present?
      @sheets = @sheets.where(risk_level: params[:risk_level])
    end
  end

  def show
    @sheet = ConsultationSheet.find(params[:id])
    @audits = @sheet.audits.order(created_at: :desc)
  end

  def create
    @sheet = ConsultationSheet.new(sheet_params)

    if @sheet.save
      render json: {
        id: @sheet.id,
        status: @sheet.status,
        message: "КЛ добавлен в очередь на обработку"
      }, status: :created
    else
      render json: { errors: @sheet.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def bulk_create
    uploaded_files = params[:files] || []
    batch_name = params[:batch_name] || "Batch #{Time.current.strftime('%Y-%m-%d %H:%M')}"

    batch = AuditBatch.create!(
      name: batch_name,
      total_sheets: uploaded_files.length,
      processed_sheets: 0,
      status: :pending
    )

    uploaded_files.each do |file|
      content = extract_content_from_file(file)

      ConsultationSheet.create!(
        patient_name: extract_patient_name(content),
        patient_id: extract_patient_id(content),
        diagnosis: extract_diagnosis(content),
        content: content,
        audit_batch: batch,
        raw_file: file.read
      )
    end

    render json: {
      batch_id: batch.id,
      total: batch.total_sheets,
      message: "Batch создан, начинается обработка"
    }
  end

  private

  def sheet_params
    params.require(:consultation_sheet).permit(
      :patient_name, :patient_id, :diagnosis, :content
    )
  end

  def extract_content_from_file(file)
    case file.content_type
    when "application/pdf"
      extract_from_pdf(file)
    when /word/, /msword/
      extract_from_docx(file)
    when "text/plain"
      file.read
    else
      raise "Unsupported file type: #{file.content_type}"
    end
  end

  def extract_from_pdf(file)
    reader = PDF::Reader.new(file.tempfile)
    reader.pages.map(&:text).join("\n\n")
  end

  def extract_from_docx(file)
    Docx::Document.open(file.tempfile).paragraphs.map(&:text).join("\n")
  end

  def extract_patient_name(content)
    # Простое извлечение - можно улучшить с помощью regex или NER
    match = content.match(/ФИО[:\s]+([А-ЯЁа-яё\s]+)/i)
    match ? match[1].strip : "Не указано"
  end

  def extract_patient_id(content)
    match = content.match(/ИИН[:\s]+(\d{12})/i)
    match ? match[1] : nil
  end

  def extract_diagnosis(content)
    match = content.match(/Диагноз[:\s]+([^\n]+)/i)
    match ? match[1].strip : "Не указан"
  end
end
