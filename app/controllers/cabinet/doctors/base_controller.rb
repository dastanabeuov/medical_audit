# frozen_string_literal: true

module Cabinet
  module Doctors
    class BaseController < ApplicationController
      before_action :authenticate_doctor!
      layout "cabinet"

      private

      def current_user
        current_doctor
      end
    end
  end
end
