class ApplicationJob < ActiveJob::Base
  # Автоматически повторять при сбое
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Настройка очереди
  queue_as :default
end
