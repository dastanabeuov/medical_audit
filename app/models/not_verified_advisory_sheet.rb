class NotVerifiedAdvisorySheet < ApplicationRecord
  belongs_to :auditor, optional: true

  validates :recording, presence: true
  validates :body, presence: true

  scope :pending, -> { all }
  scope :by_recording, ->(recording) { where("recording ILIKE ?", "%#{recording}%") }
  scope :by_body, ->(body) { where("body ILIKE ?", "%#{body}%") }
end
