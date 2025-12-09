Rails.application.routes.draw do
  # devise_for :doctors
  # devise_for :main_doctors
  # devise_for :auditors

  root to: "home#index"
  get "up" => "rails/health#show", as: :rails_health_check

  scope :cabinet do
    devise_for :auditors, controllers:     { sessions:     "cabinet/auditors/sessions" }
    devise_for :main_doctors, controllers: { sessions:     "cabinet/main_doctors/sessions" }
    devise_for :doctors, controllers:      { sessions:     "cabinet/doctors/sessions" }
  end
end
