# frozen_string_literal: true

module Cabinet
  module Auditors
    class RegistrationsController < Devise::RegistrationsController
      layout "auditor"

      before_action :configure_sign_up_params, only: [ :create ]
      before_action :configure_account_update_params, only: [ :update ]

      # GET /cabinet/auditors/register
      def new
        super
      end

      # POST /cabinet/auditors
      def create
        super
      end

      # GET /cabinet/auditors/edit
      def edit
        super
      end

      # PUT /cabinet/auditors
      def update
        super
      end

      # DELETE /cabinet/auditors
      def destroy
        super
      end

      protected

      # If you have extra params to permit, append them to the sanitizer.
      def configure_sign_up_params
        devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name, :position, :preferred_locale ])
      end

      # If you have extra params to permit, append them to the sanitizer.
      def configure_account_update_params
        devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name, :position, :preferred_locale ])
      end

      # The path used after sign up.
      def after_sign_up_path_for(resource)
        cabinet_auditors_dashboard_path
      end

      # The path used after sign up for inactive accounts.
      def after_inactive_sign_up_path_for(resource)
        new_auditor_session_path
      end
    end
  end
end
