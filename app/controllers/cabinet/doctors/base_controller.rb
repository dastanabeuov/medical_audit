# frozen_string_literal: true

module Cabinet
  module Doctors
    class BaseController < ApplicationController
      before_action :authenticate_doctor!
      layout "doctor"

      private

      def current_user
        current_doctor
      end
    end
  end
end
