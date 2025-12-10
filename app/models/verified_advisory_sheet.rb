class VerifiedAdvisorySheet < ApplicationRecord
  belongs_to :auditor, optional: true

  enum :status, { red: 0, yellow: 1, green: 2 }

  validates :recording, presence: true
  validates :body, presence: true
  validates :status, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :by_recording, ->(recording) { where("recording ILIKE ?", "%#{recording}%") }
  scope :by_body, ->(body) { where("body ILIKE ?", "%#{body}%") }
  # scope :search, ->(query) {
  #   return all if query.blank?
  #   where("recording ILIKE :q OR body ILIKE :q", q: "%#{query}%")
  # }

  def status_color
    case status
    when "red" then "#EF4444"
    when "yellow" then "#F59E0B"
    when "green" then "#10B981"
    end
  end

  def status_label
    case status
    when "red" then "Не соответствует"
    when "yellow" then "Частичное соответствие"
    when "green" then "Соответствует"
    end
  end
end
