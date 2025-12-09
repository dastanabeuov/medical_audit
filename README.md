# Medical Audit System

> AI-powered система для автоматизированного аудита медицинских консультативных листов (КЛ) на соответствие МКБ-10/11 и протоколам МЗ РК

## Описание

Medical Audit System - это Rails 8 приложение, использующее технологию RAG (Retrieval-Augmented Generation) для автоматического аудита медицинских консультативных листов.

### Проблема

Медицинские аудиторы тратят часы на ручную проверку сотен консультативных листов, сверяя их с МКБ и протоколами МЗ РК.

### Решение

Система автоматически:
1. Загружает и обрабатывает 100+ КЛ одновременно
2. Извлекает ключевую информацию (диагноз, лечение, обследования)
3. Сопоставляет с базой знаний (МКБ + Протоколы)
4. Выявляет нарушения и несоответствия
5. Выставляет оценку 0-100 и классифицирует по цветам:
   - **Красный** (< 50) - критические нарушения
   - **Желтый** (50-80) - есть замечания
   - **Зеленый** (80+) - соответствует стандартам

**Результат**: Аудиторы сразу видят проблемные КЛ (красные) и могут сосредоточиться на них, вместо проверки всех подряд.

---

## Возможности

### 🤖 AI-Powered Analysis
- **RAG Pipeline**: Векторный поиск + semantic search по базе знаний
- **Claude Sonnet 4**: Глубокий анализ соответствия протоколам
- **Smart Chunking**: Автоматическая разбивка больших документов
- **Context Window Management**: Оптимальное использование контекста

### Batch Processing
- Одновременная обработка 100+ документов
- Асинхронная обработка через Solid Queue
- Real-time progress tracking
- Автоматический retry при ошибках

### File Processing
- Поддержка форматов: PDF, DOCX, TXT
- Автоматическое извлечение текста
- Парсинг структурированных данных (ФИО, ИИН, диагноз)
- Drag & Drop интерфейс

### Modern UI
- Tailwind CSS для современного дизайна
- Real-time обновления через ActionCable
- Интерактивные дашборды
- Детальные отчеты с рекомендациями

### Analytics & Reporting
- Статистика по batch
- Топ нарушений
- Экспорт в PDF
- API для интеграций


---

## Технологический стек

### Backend
- **Ruby** 3.4.3 - Язык программирования
- **Rails** 8.0.4 - Web framework
- **PostgreSQL** 17 - База данных с pgvector extension
- **Solid Queue** - Background jobs (Rails 8 default)
- **Solid Cache** - Caching (Rails 8 default)
- **Solid Cable** - WebSocket (Rails 8 default)

### Frontend
- **Tailwind CSS** - Utility-first CSS framework
- **Stimulus** - JavaScript framework
- **Turbo** - SPA-like experience
- **ActionCable** - Real-time WebSocket

### AI & ML
- **Ruby LLM** - Unified AI interface
- **Claude Sonnet 4** (Anthropic) - Main analysis model
- **OpenAI Embeddings** (text-embedding-3-large) - Vector search
- **pgvector** - Vector similarity search
- **Neighbor gem** - pgvector integration

### File Processing
- **pdf-reader** - PDF parsing
- **docx** - DOCX parsing
- **roo** - Excel support
- **ruby-vips** - Image processing

### DevOps & Monitoring
- **Thruster** - HTTP/2 proxy (Rails 8)
- **Mission Control** - Job monitoring
- **Bullet** - N+1 queries detection
- **Annotate** - Schema comments

```


### Базовый workflow

Откройте браузер: http://localhost:3000

#### Создание нового batch
```bash
# Через UI
1. Перейдите на http://localhost:3000/audit_batches
2. Нажмите "Create New Batch"
3. Введите название batch
4. Загрузите файлы (PDF, DOCX, TXT)
5. Нажмите "Upload & Process"

# Через Rails Console
batch = AuditBatch.create!(
  name: "January 2024 Audit",
  total_sheets: 0
)

# Добавление КЛ
ConsultationSheet.create!(
  audit_batch: batch,
  patient_name: "Жандос К.Л.",
  patient_id: "123456789012",
  diagnosis: "Гипертоническая болезнь",
  content: File.read("path/to/consultation_sheet.txt")
)

# Обработка будет запущена автоматически
```

#### Экспорт отчетов
```ruby
# Rails Console
batch = AuditBatch.find(1)

# JSON отчет
report = ReportGeneratorService.new(batch).generate_summary_report
puts JSON.pretty_generate(report)

# PDF отчет
pdf = ReportGeneratorService.new(batch).generate_pdf_report
File.write("report_batch_#{batch.id}.pdf", pdf)
```

### CLI Commands

```bash
# Rake tasks для управления базой знаний

# Импорт документов
rails knowledge:import[data/knowledge]

# Поиск в базе знаний
rails knowledge:search["артериальная гипертензия"]

# Переиндексация embeddings
rails knowledge:reindex

# Статистика
rails knowledge:stats
```

### Rails Console Commands

```ruby
# Запуск console
rails console

# === Работа с базой знаний ===

# Поиск документов
KnowledgeDocument.search("гипертензия", limit: 5)

# Создание документа с chunking
KnowledgeDocument.create_with_chunking(
  title: "Протокол диагностики АГ",
  content: File.read("protocol.txt"),
  document_type: :protocol,
  source: "МЗ РК 2023"
)

# === Работа с консультативными листами ===

# Создание КЛ
sheet = ConsultationSheet.create!(
  patient_name: "Петров П.П.",
  diagnosis: "J18 Пневмония",
  content: "..."
)

# Запуск анализа
sheet.analyze!

# Проверка результата
sheet.score          # => 67.5
sheet.risk_level     # => "yellow"
sheet.findings       # => { violations: [...], strengths: [...] }

# === Batch операции ===

# Создание batch
batch = AuditBatch.create!(name: "Test Batch")

# Добавление КЛ к batch
sheet.update!(audit_batch: batch)
batch.update!(total_sheets: batch.consultation_sheets.count)

# Запуск обработки
batch.process!

# === RAG тестирование ===

# Тест retriever
retriever = RagRetrieverService.new("лечение гипертонии")
context = retriever.retrieve_context_window(limit: 5)
puts context

# Тест analyzer
analyzer = AuditAnalyzerService.new(sheet)
result = analyzer.analyze
puts result.to_yaml
```


### --REST Endpoints--

#### Batches

```http
GET /audit_batches
# Список всех batch

GET /audit_batches/:id
# Детали batch

GET /audit_batches/:id/summary
# Краткая статистика batch

POST /audit_batches
# Создание нового batch

DELETE /audit_batches/:id
# Удаление batch
```

#### Consultation Sheets

```http
GET /consultation_sheets
# Список КЛ (с фильтрами)

GET /consultation_sheets/:id
# Детали КЛ

POST /consultation_sheets
# Создание одного КЛ

POST /consultation_sheets/bulk_create
# Bulk создание КЛ

POST /consultation_sheets/:id/reanalyze
# Повторный анализ КЛ
```

#### Knowledge Base

```http
GET /knowledge_documents
# Список документов

GET /knowledge_documents/:id
# Детали документа

GET /knowledge_documents/search?q=query&limit=10
# Поиск документов

POST /knowledge_documents
# Создание документа

POST /knowledge_documents/import
# Bulk импорт документов
```

---

## Testing

```bash
# Setup test database
RAILS_ENV=test rails db:setup

# Run all tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/models/consultation_sheet_spec.rb

# With coverage
COVERAGE=true bundle exec rspec

# Run system tests
bundle exec rspec spec/system
