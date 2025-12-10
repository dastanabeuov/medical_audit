# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  # Devise routes для трех типов пользователей
  scope :cabinet do
    devise_for :auditors,
               controllers: { sessions: "cabinet/auditors/sessions" },
               path: "auditors",
               path_names: { sign_in: "login", sign_out: "logout" }

    devise_for :main_doctors,
               controllers: { sessions: "cabinet/main_doctors/sessions" },
               path: "main_doctors",
               path_names: { sign_in: "login", sign_out: "logout" }

    devise_for :doctors,
               controllers: { sessions: "cabinet/doctors/sessions" },
               path: "doctors",
               path_names: { sign_in: "login", sign_out: "logout" }
  end

  # Кабинет аудитора
  namespace :cabinet do
    namespace :auditors do
      get "dashboard", to: "dashboard#index"
      resources :advisory_sheets, only: [ :index, :show, :create ] do
        collection do
          get :upload
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
