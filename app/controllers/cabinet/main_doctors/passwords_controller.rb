# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class PasswordsController < Devise::PasswordsController
      layout "main_doctor"

      # GET /cabinet/main_doctors/password/new
      def new
        super
      end

      # POST /cabinet/main_doctors/password
      def create
        super
      end

      # GET /cabinet/main_doctors/password/edit?reset_password_token=abcdef
      def edit
        super
      end

      # PUT /cabinet/main_doctors/password
      def update
        super
      end

      protected

      def after_resetting_password_path_for(resource)
        cabinet_main_doctors_dashboard_path
      end

      # The path used after sending reset password instructions
      def after_sending_reset_password_instructions_path_for(resource_name)
        new_main_doctor_session_path
      end
    end
  end
end
