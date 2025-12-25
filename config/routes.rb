# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  # Devise routes для трех типов пользователей
  scope :cabinet do
    devise_for :auditors,
               controllers: {
                 sessions: "cabinet/auditors/sessions",
                 registrations: "cabinet/auditors/registrations",
                 passwords: "cabinet/auditors/passwords",
                 confirmations: "cabinet/auditors/confirmations",
                 unlocks: "cabinet/auditors/unlocks"
               },
               path: "auditors",
               path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" }

    devise_for :main_doctors,
               controllers: {
                 sessions: "cabinet/main_doctors/sessions",
                 registrations: "cabinet/main_doctors/registrations",
                 passwords: "cabinet/main_doctors/passwords",
                 confirmations: "cabinet/main_doctors/confirmations",
                 unlocks: "cabinet/main_doctors/unlocks"
               },
               path: "main_doctors",
               path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" }

    devise_for :doctors,
               controllers: {
                 sessions: "cabinet/doctors/sessions",
                 registrations: "cabinet/doctors/registrations",
                 passwords: "cabinet/doctors/passwords",
                 confirmations: "cabinet/doctors/confirmations",
                 unlocks: "cabinet/doctors/unlocks"
               },
               path: "doctors",
               path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" }
  end

  # Кабинет аудитора
  namespace :cabinet do
    namespace :auditors do
      get "dashboard", to: "dashboard#index"
      resources :advisory_sheets do
        collection do
          get :upload
        end
      end

      # Список врачей с учетными данными
      resources :doctors, only: [ :index ]

      # Отчеты
      resource :reports, only: [] do
        collection do
          get :export  # GET /cabinet/auditors/reports/export.csv
          get :summary # GET /cabinet/auditors/reports/summary
        end
      end
    end

    # Кабинет главного врача
    namespace :main_doctors do
      get "dashboard", to: "dashboard#index"
    end

    # Кабинет врача
    namespace :doctors do
      get "dashboard", to: "dashboard#index"
    end
  end

  # Sidekiq Web UI (только для разработки)
  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
