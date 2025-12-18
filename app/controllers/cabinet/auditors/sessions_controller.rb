# frozen_string_literal: true

module Cabinet
  module Auditors
    class SessionsController < Devise::SessionsController
      layout "auditor"

      protected

      def after_sign_in_path_for(_resource)
        cabinet_auditors_dashboard_path
      end

      def after_sign_out_path_for(_resource_or_scope)
        root_path
      end
    end
  end
end
