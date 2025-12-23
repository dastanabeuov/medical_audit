# Руководство по системе отчетов

## Обзор

Система отчетов предоставляет полный функционал для экспорта данных о качестве заполнения консультативных листов в формате CSV.

## Архитектура (следуя Best Practices)

### Разделение ответственности (Separation of Concerns)

1. **AdvisorySheetReportService** - отвечает ТОЛЬКО за подготовку данных
2. **ReportsController** - отвечает ТОЛЬКО за HTTP логику
3. **Rake tasks** - отвечают ТОЛЬКО за CLI интерфейс

### Принцип единственной ответственности (Single Responsibility)

Каждый компонент выполняет одну задачу:
- Сервис генерирует данные (не знает о CSV)
- Контроллер форматирует в CSV (не знает о бизнес-логике)
- Rake таски управляют процессом (не знают о HTTP)

## Использование через Web-интерфейс

### Экспорт отчета

1. Откройте страницу списка консультативных листов
2. Нажмите кнопку **"Экспорт CSV"** (зеленая кнопка с иконкой)
3. Файл автоматически скачается с именем `advisory_sheets_report_YYYYMMDD_HHMMSS.csv`

### Фильтрация перед экспортом

Отчет учитывает текущие фильтры:

- **По статусу** - выберите нужный таб (Все, Красный, Желтый, Зеленый, Фиолетовый)
- **По поиску** - введите текст в поле поиска перед экспортом

Пример: экспорт только "красных" листов
```
1. Перейдите на таб "Не соответствует"
2. Нажмите "Экспорт CSV"
3. Получите файл только с красными листами
```

## Использование через CLI (Rake tasks)

### Доступные команды

#### 1. Извлечение полей
```bash
rake advisory_sheets:extract_fields
```
Извлекает ключевые поля для всех листов, у которых их еще нет.

#### 2. Расчет оценок
```bash
rake advisory_sheets:calculate_scores
```
Рассчитывает оценки качества для листов с полями, но без оценок.

#### 3. Пересчет существующих оценок
```bash
rake advisory_sheets:recalculate_scores
```
Пересчитывает все существующие оценки (полезно при изменении алгоритма).

#### 4. Полная обработка
```bash
rake advisory_sheets:full_process
```
Выполняет полный цикл: извлечение полей → расчет оценок.

#### 5. Статистика
```bash
rake advisory_sheets:stats
```
Выводит подробную статистику по качеству заполнения.

### Примеры вывода

**advisory_sheets:stats**
```
================================================================================
СТАТИСТИКА ПО КОНСУЛЬТАТИВНЫМ ЛИСТАМ
================================================================================

Всего листов: 245
С извлеченными полями: 245 (100.0%)
С оценками качества: 245 (100.0%)

СТАТИСТИКА ПО КАЧЕСТВУ:
--------------------------------------------------------------------------------
Средний балл: 7.2 из 9.0
Средний процент: 80.0%

РАСПРЕДЕЛЕНИЕ ПО КАЧЕСТВУ:
  Отличное (90-100%):        45
  Хорошее (80-89%):          120
  Удовлетворительное (60-79%): 65
  Требует улучшения (30-59%): 12
  Критично низкое (<30%):    3

СРЕДНИЕ БАЛЛЫ ПО ПОЛЯМ:
  Жалобы: 0.92 / 1.0
  Anamnesis morbi: 0.85 / 1.0
  Anamnesis vitae: 0.78 / 1.0
  ...
================================================================================
```

## Использование через Rails Console

### Генерация данных отчета

```ruby
# Все листы
data = AdvisorySheetReportService.generate_report_data

# Только определенные листы
sheets = VerifiedAdvisorySheet.where(status: :red)
data = AdvisorySheetReportService.generate_report_data(sheets)

# Доступ к данным
data.first.recording          # => "12345"
data.first.total_score        # => 7.5
data.first.percentage         # => 83.33
data.first.quality_label      # => "Хорошее качество"
```

### Получение сводной статистики

```ruby
summary = AdvisorySheetReportService.generate_summary

summary[:total_sheets]        # => 245
summary[:average_total_score] # => 7.2
summary[:average_percentage]  # => 80.0

# По статусам
summary[:by_status]
# => {"Соответствует"=>120, "Частичное"=>80, ...}

# По качеству
summary[:by_quality]
# => {:excellent=>45, :good=>120, :satisfactory=>65, ...}

# Средние баллы по полям
summary[:field_averages]
# => {:complaints=>0.92, :anamnesis_morbi=>0.85, ...}
```

### Работа с оценками

```ruby
# Оценить один лист
sheet = VerifiedAdvisorySheet.first
AdvisorySheetScoringService.score_sheet(sheet)

# Массовая оценка
AdvisorySheetScoringService.score_all

# Получить листы с низким качеством
low = AdvisorySheetScoringService.low_quality_sheets(limit: 20)

# Получить листы с высоким качеством
high = AdvisorySheetScoringService.high_quality_sheets(limit: 20)
```

## Формат CSV отчета

### Заголовки

1. Номер записи
2. Исходный файл
3. Статус проверки
4. Дата проверки
5. Жалобы (балл)
6. Anamnesis morbi (балл)
7. Anamnesis vitae (балл)
8. Объективный осмотр (балл)
9. Протокол исследования (балл)
10. Диагнозы (балл)
11. Направления (балл)
12. Назначения (балл)
13. Рекомендации (балл)
14. Итоговый балл
15. Процент качества
16. Оценка качества

### Особенности формата

- **Разделитель**: точка с запятой (`;`)
- **Кодировка**: UTF-8 с BOM (для корректного открытия в Excel)
- **Баллы**: 0.0, 0.5, или 1.0
- **Процент**: от 0.00 до 100.00
- **Дата**: формат `ДД.ММ.ГГГГ ЧЧ:ММ`

## API контроллера

### GET /cabinet/auditors/reports/export.csv

Экспортирует отчет в формате CSV.

**Параметры (опциональные):**
- `status` - фильтр по статусу (red, yellow, green, purple)
- `from_date` - начальная дата (YYYY-MM-DD)
- `to_date` - конечная дата (YYYY-MM-DD)
- `min_percentage` - минимальный процент качества

**Примеры:**

```
# Все листы
GET /cabinet/auditors/reports/export.csv

# Только красные
GET /cabinet/auditors/reports/export.csv?status=red

# За период
GET /cabinet/auditors/reports/export.csv?from_date=2025-01-01&to_date=2025-01-31

# С минимальным качеством 80%
GET /cabinet/auditors/reports/export.csv?min_percentage=80

# Комбинация фильтров
GET /cabinet/auditors/reports/export.csv?status=yellow&min_percentage=50
```

## Производительность

- **Генерация отчета для 1000 листов**: ~500-1000ms
- **Размер CSV для 1000 листов**: ~200-300KB
- **Rake task для 1000 листов**: ~30-60 секунд (включая извлечение полей и оценку)

## Мониторинг и отладка

### Логирование

Все операции логируются в `log/production.log`:

```ruby
# Примеры логов
AdvisorySheetReportService: Generating report for 245 sheets
ReportsController: CSV export completed in 523ms
AdvisorySheetScoringService: Scored 100 sheets, 98 successful, 2 failed
```

### Отладка через консоль

```ruby
# Проверить, сколько листов без полей
VerifiedAdvisorySheet.left_joins(:advisory_sheet_field)
                     .where(advisory_sheet_fields: { id: nil })
                     .count

# Проверить, сколько листов без оценок
VerifiedAdvisorySheet.joins(:advisory_sheet_field)
                     .left_joins(:advisory_sheet_score)
                     .where(advisory_sheet_scores: { id: nil })
                     .count
```

## Расширение функциональности

### Добавление новых форматов экспорта (XLSX, PDF)

1. Добавьте gem в Gemfile:
```ruby
gem 'caxlsx' # для XLSX
```

2. Обновите контроллер:
```ruby
respond_to do |format|
  format.csv { send_csv_report }
  format.xlsx { send_xlsx_report }  # Новый формат
end
```

3. Сервис остается без изменений (принцип SRP)

### Добавление новых полей в отчет

1. Обновите `ReportRow` структуру в `AdvisorySheetReportService`
2. Обновите метод `build_report_row`
3. Добавьте заголовок в `report_headers`
4. Добавьте значение в `row_to_array`

## Интеграция с Google Sheets

Для автоматического экспорта в Google Sheets:

1. Установите gem `google-apis-sheets_v4`
2. Создайте service account в Google Cloud Console
3. Создайте отдельный сервис `GoogleSheetsExportService`
4. Используйте данные из `AdvisorySheetReportService`

Пример структуры:
```ruby
class GoogleSheetsExportService
  def export(sheet_id)
    data = AdvisorySheetReportService.generate_report_data
    # Логика экспорта в Google Sheets
  end
end
```

## Безопасность

- Доступ к экспорту только для авторизованных аудиторов
- Проверка прав через `Cabinet::Auditors::BaseController`
- Фильтрация данных на уровне контроллера
- Без SQL injection (используется ActiveRecord)

## Тестирование

```bash
# Тестовая генерация отчета
rails runner "puts AdvisorySheetReportService.generate_report_data.count"

# Тестовая статистика
rails runner "pp AdvisorySheetReportService.generate_summary"
```
