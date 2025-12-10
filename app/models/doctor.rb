class Doctor < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :timeoutable,
         :trackable and :omniauthable

  belongs_to :main_doctor, optional: true

  validates :email, presence: true, uniqueness: true

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end
end
