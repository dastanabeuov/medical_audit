class MainDoctor < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable,
         :trackable and :omniauthable

  has_many :doctors, dependent: :nullify

  validates :email, presence: true, uniqueness: true

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end
end
