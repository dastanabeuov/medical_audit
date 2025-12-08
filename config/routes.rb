Rails.application.routes.draw do
  devise_for :auditors

  scope :doctors do
    devise_for :doctors, controllers: { sessions: "doctor/doctors/sessions" }
  end

  scope :main_doctors do
    devise_for :main_doctors, controllers: { sessions: "main_doctor/main_doctors/sessions" }
  end

  root to: "home#index"
  get "up" => "rails/health#show", as: :rails_health_check
end
