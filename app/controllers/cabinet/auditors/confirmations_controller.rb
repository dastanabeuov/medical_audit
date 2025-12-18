# frozen_string_literal: true

module Cabinet
  module Auditors
    class ConfirmationsController < Devise::ConfirmationsController
      layout "auditor"

      protected

      def after_confirmation_path_for(_resource_name, resource)
        cabinet_auditors_dashboard_path
      end
    end
  end
end
