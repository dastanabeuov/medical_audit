class ConsultationSheet < ApplicationRecord
  has_many :audits, dependent: :destroy
  belongs_to :audit_batch, optional: true

  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  enum risk_level: {
    green: 0,    # Соответствует протоколам (score >= 80)
    yellow: 1,   # Есть замечания (50 <= score < 80)
    red: 2       # Критические нарушения (score < 50)
  }

  validates :patient_name, :diagnosis, :content, presence: true
  validates :score, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }, allow_nil: true

  after_commit :process_async, on: :create

  # Основной метод анализа
  def analyze!
    update!(status: :processing)

    result = AuditAnalyzerService.new(self).analyze

    update!(
      status: :completed,
      score: result[:score],
      risk_level: calculate_risk_level(result[:score]),
      findings: result[:findings]
    )

    create_audit_record(result)
  rescue => e
    update!(status: :failed, findings: { error: e.message })
    raise
  end

  private

  def process_async
    ConsultationSheetAnalysisJob.perform_later(id)
  end

  def calculate_risk_level(score)
    case score
    when 80..100 then :green
    when 50...80 then :yellow
    else :red
    end
  end

  def create_audit_record(result)
    audits.create!(
      analysis: result,
      created_at: Time.current
    )
  end
end
