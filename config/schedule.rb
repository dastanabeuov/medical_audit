# frozen_string_literal: true

# Используйте этот файл для настройки периодических задач через гем whenever
# Документация: https://github.com/javan/whenever
#
# После изменений выполните: whenever --update-crontab
# Для просмотра текущих задач: crontab -l
# Для очистки: whenever --clear-crontab

# Устанавливаем переменные окружения
set :output, "log/cron.log"
env :PATH, ENV["PATH"]
set :environment, ENV.fetch("RAILS_ENV", "development")

# Импорт врачей из medelement.com
# Запускается каждую ночь в 2:00
every 1.day, at: "2:00 AM" do
  rake "doctors:import_from_medelement", output: "log/medelement_import.log"
end

# Альтернативный вариант: каждые 12 часов
# every 12.hours do
#   rake "doctors:import_from_medelement", output: "log/medelement_import.log"
# end

# Альтернативный вариант: каждый понедельник в 3:00
# every :monday, at: "3:00 AM" do
#   rake "doctors:import_from_medelement", output: "log/medelement_import.log"
# end
