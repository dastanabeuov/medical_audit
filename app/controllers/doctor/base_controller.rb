class Doctor::BaseController < ApplicationController
  layout "doctor"
  before_action :authenticate_doctor!

  def current_ability
    @current_ability ||= Ability.new(current_doctor)
  end
end
