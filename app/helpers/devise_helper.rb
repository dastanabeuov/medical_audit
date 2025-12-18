# frozen_string_literal: true

module DeviseHelper
  # Определение цветовой схемы на основе scope
  def theme_color(resource_name = nil)
    scope = resource_name || devise_mapping&.name

    case scope.to_s
    when "auditor", "auditors"
      "red"
    when "main_doctor", "main_doctors"
      "blue"
    when "doctor", "doctors"
      "green"
    else
      "gray"
    end
  end

  # Иконка для scope
  def scope_icon_svg(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      <<~HTML.html_safe
        <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
      HTML
    when "main_doctor", "main_doctors"
      <<~HTML.html_safe
        <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
        </svg>
      HTML
    when "doctor", "doctors"
      <<~HTML.html_safe
        <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
        </svg>
      HTML
    end
  end

  # Tailwind классы для фона иконки
  def icon_bg_class(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      "bg-red-100"
    when "main_doctor", "main_doctors"
      "bg-blue-100"
    when "doctor", "doctors"
      "bg-green-100"
    else
      "bg-gray-100"
    end
  end

  # Tailwind классы для input полей
  def input_focus_class(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      "focus:border-red-500 focus:ring-red-500"
    when "main_doctor", "main_doctors"
      "focus:border-blue-500 focus:ring-blue-500"
    when "doctor", "doctors"
      "focus:border-green-500 focus:ring-green-500"
    else
      "focus:border-gray-500 focus:ring-gray-500"
    end
  end

  # Tailwind классы для кнопок
  def button_class(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      "w-full flex justify-center py-2.5 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors duration-200"
    when "main_doctor", "main_doctors"
      "w-full flex justify-center py-2.5 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors duration-200"
    when "doctor", "doctors"
      "w-full flex justify-center py-2.5 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 transition-colors duration-200"
    else
      "w-full flex justify-center py-2.5 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-gray-600 hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 transition-colors duration-200"
    end
  end

  # Tailwind классы для checkbox
  def checkbox_class(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      "h-4 w-4 text-red-600 focus:ring-red-500 border-gray-300 rounded"
    when "main_doctor", "main_doctors"
      "h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
    when "doctor", "doctors"
      "h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded"
    else
      "h-4 w-4 text-gray-600 focus:ring-gray-500 border-gray-300 rounded"
    end
  end

  # Tailwind классы для ссылок
  def link_class(resource_name)
    case resource_name.to_s
    when "auditor", "auditors"
      "text-red-600 hover:text-red-800 font-medium transition-colors duration-200"
    when "main_doctor", "main_doctors"
      "text-blue-600 hover:text-blue-800 font-medium transition-colors duration-200"
    when "doctor", "doctors"
      "text-green-600 hover:text-green-800 font-medium transition-colors duration-200"
    else
      "text-gray-600 hover:text-gray-800 font-medium transition-colors duration-200"
    end
  end

  # Заголовок для scope
  def scope_title(action, resource_name)
    t("views.devise.#{action}.title.#{resource_name}")
  rescue
    resource_name.to_s.humanize
  end
end
