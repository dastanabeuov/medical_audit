# frozen_string_literal: true

module Cabinet
  module MainDoctors
    class BaseController < ApplicationController
      before_action :authenticate_main_doctor!
      layout "main_doctor"

      private

      def current_user
        current_main_doctor
      end
    end
  end
end
