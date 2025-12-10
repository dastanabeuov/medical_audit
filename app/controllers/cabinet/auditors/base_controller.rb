# frozen_string_literal: true

module Cabinet
  module Auditors
    class BaseController < ApplicationController
      before_action :authenticate_auditor!
      layout "cabinet"

      private

      def current_user
        current_auditor
      end
    end
  end
end
