class MainDoctor < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable,
         :trackable and :omniauthable

  has_many :doctors, dependent: :nullify

  has_many :relationships_main_doctor_and_verified_advisory_sheets, class_name: "RelationshipMainDoctorAndVerifiedAdvisorySheet"
  has_many :verified_advisory_sheets, through: :relationships_main_doctor_and_verified_advisory_sheets

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :department, presence: true
  validates :specialization, presence: true
  validates :clinic, presence: true
  validates :date_of_employment, presence: true

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end
end
