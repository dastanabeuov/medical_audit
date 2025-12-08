class MainDoctor::BaseController < ApplicationController
  layout "main_doctor"
  before_action :authenticate_doctor!

  def current_ability
    @current_ability ||= Ability.new(current_main_doctor)
  end
end
