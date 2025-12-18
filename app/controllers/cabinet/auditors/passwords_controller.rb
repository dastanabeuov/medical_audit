# frozen_string_literal: true

module Cabinet
  module Auditors
    class PasswordsController < Devise::PasswordsController
      layout "auditor"

      # GET /cabinet/auditors/password/new
      def new
        super
      end

      # POST /cabinet/auditors/password
      def create
        super
      end

      # GET /cabinet/auditors/password/edit?reset_password_token=abcdef
      def edit
        super
      end

      # PUT /cabinet/auditors/password
      def update
        super
      end

      protected

      def after_resetting_password_path_for(resource)
        cabinet_auditors_dashboard_path
      end

      # The path used after sending reset password instructions
      def after_sending_reset_password_instructions_path_for(resource_name)
        new_auditor_session_path
      end
    end
  end
end
