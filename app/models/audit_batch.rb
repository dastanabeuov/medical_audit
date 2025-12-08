class AuditBatch < ApplicationRecord
  has_many :consultation_sheets, dependent: :destroy

  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :name, presence: true

  after_create :process_batch_async

  def process!
    update!(status: :processing)

    consultation_sheets.pending.find_each do |sheet|
      ConsultationSheetAnalysisJob.perform_later(sheet.id)
    end
  end

  def update_progress!
    update!(
      processed_sheets: consultation_sheets.where.not(status: :pending).count,
      status: all_completed? ? :completed : :processing
    )
  end

  def completion_percentage
    return 0 if total_sheets.zero?
    (processed_sheets.to_f / total_sheets * 100).round(2)
  end

  def risk_summary
    {
      red: consultation_sheets.red.count,
      yellow: consultation_sheets.yellow.count,
      green: consultation_sheets.green.count
    }
  end

  private

  def all_completed?
    processed_sheets == total_sheets
  end

  def process_batch_async
    BatchProcessorJob.perform_later(id)
  end
end
