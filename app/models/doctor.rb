class Doctor < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable,
         :trackable and :omniauthable

  belongs_to :main_doctor, optional: true

  has_many :relationships_doctor_and_verified_advisory_sheets, class_name: "RelationshipDoctorAndVerifiedAdvisorySheet"
  has_many :verified_advisory_sheets, through: :relationships_doctor_and_verified_advisory_sheets

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :department, presence: true
  validates :specialization, presence: true
  validates :clinic, presence: true
  validates :date_of_employment, presence: true

  def full_name
    [ last_name, first_name, second_name ].compact.join(" ").presence || email
  end
end
