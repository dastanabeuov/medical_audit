# frozen_string_literal: true

module Cabinet
  module Auditors
    module AdvisorySheetsHelper
      # Возвращает CSS класс для цвета баллов
      # @param score [Float] - балл (0.0, 0.5, или 1.0)
      # @return [String] - CSS класс цвета
      def score_color_class(score)
        case score
        when 1.0 then "text-green-600"
        when 0.5 then "text-yellow-600"
        else "text-red-600"
        end
      end
    end
  end
end
