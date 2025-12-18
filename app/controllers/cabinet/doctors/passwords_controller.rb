# frozen_string_literal: true

module Cabinet
  module Doctors
    class PasswordsController < Devise::PasswordsController
      layout "doctor"

      # GET /cabinet/doctors/password/new
      def new
        super
      end

      # POST /cabinet/doctors/password
      def create
        super
      end

      # GET /cabinet/doctors/password/edit?reset_password_token=abcdef
      def edit
        super
      end

      # PUT /cabinet/doctors/password
      def update
        super
      end

      protected

      def after_resetting_password_path_for(resource)
        cabinet_doctors_dashboard_path
      end

      # The path used after sending reset password instructions
      def after_sending_reset_password_instructions_path_for(resource_name)
        new_doctor_session_path
      end
    end
  end
end
