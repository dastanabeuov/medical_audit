# Medical Audit System

> AI-powered система для автоматизированного аудита медицинских консультативных листов (КЛ) на соответствие МКБ-10/11 и протоколам МЗ РК

**Версия**: 1.0.0
**Статус**: В разработке

---

## Описание проекта

Medical Audit System — Rails 8 приложение, использующее технологию RAG (Retrieval-Augmented Generation) для автоматического аудита медицинских консультативных листов. Система анализирует загруженные документы, сверяет их с базой знаний (МКБ-10/11 + протоколы МЗ РК) и выставляет оценку соответствия с цветовой классификацией.

**Ключевые возможности:**
- Пакетная загрузка и обработка 100+ документов (PDF, DOCX, TXT)
- AI-анализ на основе векторного поиска (pgvector) и Gemini 2.0 Flash
- Автоматическая классификация: 🔴 Red (<50), 🟡 Yellow (50-80), 🟢 Green (80+)
- Защита персональных данных (автоматическая санитизация)
- Асинхронная обработка через Sidekiq

---

## 1. Архитектура проекта

### 1.1 Общая структура

```
┌─────────────────┐
│   Frontend      │  VueJS + Tailwind CSS + Stimulus + Turbo (Hotwire)
│  (View Layer)   │
└────────┬────────┘
         │
┌────────▼────────┐
│   Controllers   │  Namespaced: cabinet/auditors, cabinet/main_doctors, cabinet/doctors
│   (Rails MVC)   │
└────────┬────────┘
         │
┌────────▼────────┐
│    Services     │  AdvisorySheetVerificationService, GeminiService, etc.
│  (Business      │  RAG Pipeline: Sanitize → Embed → Retrieve → Verify → Save
│   Logic)        │
└────────┬────────┘
         │
┌────────▼────────┐
│     Models      │  ActiveRecord с pgvector (Neighbor gem)
│   (Data Layer)  │
└────────┬────────┘
         │
┌────────▼────────┐
│   PostgreSQL    │  17 + pgvector extension
│   + Redis       │  Vector embeddings (768d) + Sidekiq queue
└─────────────────┘

┌─────────────────┐
│  External API   │  Google Gemini API (embeddings)
└─────────────────┘
```

### 1.2 RAG Pipeline (5 этапов)

```
1. UPLOAD
   ├─ FileParserService (PDF/DOCX/TXT → text)
   └─ AdvisorySheetUploadService (создание NotVerifiedAdvisorySheet)

2. SANITIZE
   └─ PersonalDataSanitizerService (удаление ФИО, ИИН, телефонов)

3. EMBED
   └─ GeminiService.generate_embedding (text → vector 768d)

4. RETRIEVE (Hybrid Search)
   ├─ Vector similarity: Protocol.search_similar (top 5)
   └─ Text + Vector: Mkb.search_similar (top 10)

5. VERIFY & SAVE
   ├─ GeminiService.verify_advisory_sheet (AI анализ)
   └─ VerifiedAdvisorySheet.create (статус: red/yellow/green)
```

### 1.3 Структура фронтенда

**Технологии:** Rails Views (ERB/SLIM) VueJS + Tailwind CSS 4 + Hotwire (Turbo + Stimulus)

**Основные страницы:**
- `/` - Главная (home#index)
- `/cabinet/auditors/login` - Вход аудитора
- `/cabinet/auditors/dashboard` - Дашборд аудитора
- `/cabinet/auditors/advisory_sheets` - Список КЛ
- `/cabinet/auditors/advisory_sheets/upload` - Загрузка файлов
- `/cabinet/main_doctors/dashboard` - Дашборд главврача
- `/cabinet/doctors/dashboard` - Дашборд врача

**Взаимодействие с внешними сервисами:**
- **Google Gemini API**:
  - Эндпоинт: `generativelanguage.googleapis.com`
  - Методы: `embed` (embeddings), `chat` (verification)
  - Аутентификация: API Key через RubyLLM gem

### 1.4 Структура бэкенда

```
app/
├── controllers/
│   ├── cabinet/
│   │   ├── auditors/          # Контроллеры аудитора
│   │   │   ├── dashboard_controller.rb
│   │   │   ├── advisory_sheets_controller.rb
│   │   │   └── sessions_controller.rb
│   │   ├── main_doctors/      # Контроллеры главврача
│   │   └── doctors/           # Контроллеры врача
│   └── home_controller.rb
├── models/
│   ├── auditor.rb             # Devise user
│   ├── main_doctor.rb         # Devise user
│   ├── doctor.rb              # Devise user
│   ├── not_verified_advisory_sheet.rb
│   ├── verified_advisory_sheet.rb
│   ├── mkb.rb                 # ICD codes с embeddings
│   └── protocol.rb            # Протоколы с embeddings
├── services/
│   ├── advisory_sheet_upload_service.rb
│   ├── advisory_sheet_verification_service.rb  # ⭐ Главный сервис
│   ├── gemini_service.rb                       # ⭐ AI интеграция
│   ├── personal_data_sanitizer_service.rb
│   ├── file_parser_service.rb
│   ├── mkb_import_service.rb
│   └── protocol_import_service.rb
├── jobs/
│   ├── verify_advisory_sheet_job.rb
│   ├── verify_all_advisory_sheets_job.rb
│   └── import_knowledge_base_job.rb
└── views/
    ├── cabinet/
    │   ├── auditors/
    │   ├── main_doctors/
    │   └── doctors/
    └── home/
```

---

## 2. Readme для разработчика

### 2.1 Системные требования

| Компонент | Версия | Обязательно |
|-----------|--------|-------------|
| Ruby | 3.4.3 | ✅ |
| Rails | 8.0.4 | ✅ |
| PostgreSQL | 17+ | ✅ (с расширением pgvector) |
| Redis | 5.4+ | ✅ (для Sidekiq) |
| Node.js | 18+ | ✅ (для Tailwind CSS) |
| Kamal | 2+ | ⚪ (опционально, для деплоя) |
| Docker | 20+ | ⚪ (опционально, для деплоя) |

### 2.2 Установка

```bash
# 1. Клонировать репозиторий
git clone <repository-url>
cd medical_audit

# 2. Установить зависимости
bundle install

# 3. Настроить переменные окружения
cp .env.example .env
# Заполнить GEMINI_API_KEY в .env

# 4. Настроить базу данных
# Убедиться, что PostgreSQL 17 установлен и запущен
# Установить расширение pgvector:
# CREATE EXTENSION IF NOT EXISTS vector;

rails db:create
rails db:migrate

# 5. (Опционально) Загрузить seed данные
rails db:seed
```

### 2.3 Запуск в режиме разработки

```bash
# Запуск сервера + Tailwind CSS watcher
bin/dev

# Альтернативно (отдельные процессы):
# Terminal 1: Rails server
rails server -p 3000

# Terminal 2: Tailwind CSS watcher
rails tailwindcss:watch

# Terminal 3: Sidekiq (для фоновых задач)
bundle exec sidekiq
```

**Доступ:**
- Приложение: http://localhost:3000
- Sidekiq UI: http://localhost:3000/sidekiq (только development)

### 2.4 Тестирование

```bash
# Настройка тестовой БД
RAILS_ENV=test rails db:setup

# Запуск всех тестов
bundle exec rspec

# Запуск конкретного файла
bundle exec rspec spec/models/verified_advisory_sheet_spec.rb

# С покрытием кода
COVERAGE=true bundle exec rspec

# Системные тесты (с браузером)
bundle exec rspec spec/system
```

### 2.5 Проверка качества кода

```bash
# Линтер (RuboCop с Rails Omakase стилем)
bundle exec rubocop

# Автофикс
bundle exec rubocop -a

# Проверка безопасности
bundle exec brakeman

# N+1 queries detection (автоматически в development)
# Bullet покажет предупреждения в консоли/логах
```

### 2.6 Сборка для продакшена

```bash
# Precompile assets
rails assets:precompile RAILS_ENV=production

# Создание Docker образа (для Kamal)
docker build -t medical_audit:latest .

# Деплой через Kamal (см. раздел 5)
kamal deploy
```

### 2.7 Структура проекта (ключевые директории)

```
medical_audit/
├── app/                      # Основной код приложения
│   ├── controllers/          # MVC Controllers
│   ├── models/               # ActiveRecord модели
│   ├── services/             # ⭐ Бизнес-логика (RAG pipeline)
│   ├── jobs/                 # Sidekiq background jobs
│   ├── views/                # ERB шаблоны
│   └── assets/               # CSS/JS (через Propshaft)
├── config/
│   ├── database.yml          # Конфигурация БД
│   ├── deploy.yml            # ⭐ Kamal deployment config
│   ├── routes.rb             # Маршруты
│   └── initializers/
│       └── ruby_llm.rb       # ⭐ Gemini API config
├── db/
│   ├── migrate/              # Миграции БД
│   ├── schema.rb             # Схема БД
│   └── seeds.rb              # Seed данные
├── data_mkb/                 # ⭐ Исходные данные МКБ-10/11
├── data_protocol/            # ⭐ Исходные протоколы МЗ РК
├── spec/                     # RSpec тесты
│   ├── models/
│   ├── services/             # ⭐ Критичные тесты RAG логики
│   ├── jobs/
│   └── system/
├── Procfile.dev              # Foreman процессы (bin/dev)
└── Gemfile                   # Ruby зависимости
```

---

## 3. База данных

### 3.1 Обзор

**СУБД:** PostgreSQL 17
**Расширения:** pgvector (для векторного поиска)
**ORM:** ActiveRecord (Rails 8)

**Основные таблицы:** 7 таблиц + 3 Devise users

### 3.2 Схема БД

```
┌──────────────────┐
│    auditors      │ (Devise)
├──────────────────┤
│ id               │ PK
│ email            │ unique
│ first_name       │
│ last_name        │
│ position         │
│ encrypted_...    │ (Devise fields)
└────────┬─────────┘
         │ 1:N
         │
    ┌────▼────────────────────────────┐
    │                                 │
┌───▼──────────────────────┐  ┌──────▼────────────────────┐
│ not_verified_advisory... │  │ verified_advisory_sheets  │
├──────────────────────────┤  ├───────────────────────────┤
│ id                       │  │ id                        │
│ recording                │  │ recording                 │
│ body                     │  │ body                      │
│ auditor_id               │  │ status (enum: 0/1/2)      │ 🔴🟡🟢
│ original_filename        │  │ verification_result       │
│ created_at               │  │ recommendations           │
└──────────────────────────┘  │ auditor_id                │
                              │ verified_at               │
                              └───────────────────────────┘

┌──────────────────┐         ┌──────────────────┐
│   main_doctors   │ (Devise)│     doctors      │ (Devise)
├──────────────────┤         ├──────────────────┤
│ id               │ PK   ┌──│ id               │ PK
│ email            │      │  │ email            │
│ first_name       │      │  │ first_name       │
│ last_name        │      │  │ last_name        │
│ department       │      │  │ specialization   │
│ specialization   │ 1:N  └──│ main_doctor_id   │ FK
└──────────────────┘         └──────────────────┘

┌──────────────────┐         ┌──────────────────┐
│       mkbs       │         │    protocols     │
├──────────────────┤         ├──────────────────┤
│ id               │ PK      │ id               │ PK
│ code             │ unique  │ title            │
│ title            │         │ code             │
│ description      │         │ content          │
│ embedding        │ 🧮 768d │ embedding        │ 🧮 768d
│ source_file      │         │ source_file      │
└──────────────────┘         └──────────────────┘
     ↑                            ↑
     └─────── pgvector ───────────┘
     (cosine similarity search)
```

### 3.3 Ключевые таблицы

#### 3.3.1 Users (Devise, 3 модели)

| Таблица | Роль | Ключевые поля |
|---------|------|---------------|
| `auditors` | Медицинский аудитор | email, first_name, last_name, position |
| `main_doctors` | Главный врач отделения | email, first_name, last_name, department |
| `doctors` | Врач | email, first_name, last_name, specialization, main_doctor_id (FK) |

**Все используют Devise:** database_authenticatable, registerable, recoverable, rememberable, validatable, confirmable, lockable, trackable

#### 3.3.2 Advisory Sheets (Консультативные листы)

**`not_verified_advisory_sheets`** (временная таблица)
- `recording` (string, NOT NULL) - номер записи/ИИН
- `body` (text, NOT NULL) - содержимое документа
- `auditor_id` (FK → auditors)
- `original_filename` (string) - имя загруженного файла

**`verified_advisory_sheets`** (результаты проверки)
- `recording` (string, NOT NULL)
- `body` (text, NOT NULL)
- `status` (integer, enum) - **0: red, 1: yellow, 2: green**
- `verification_result` (text) - результат AI анализа
- `recommendations` (text) - рекомендации
- `auditor_id` (FK → auditors)
- `verified_at` (datetime) - время проверки

**Workflow:** NotVerifiedAdvisorySheet → (verification job) → VerifiedAdvisorySheet, затем NOT_VERIFIED удаляется.

#### 3.3.3 Knowledge Base (База знаний)

**`mkbs`** (МКБ-10/11 коды)
- `code` (string, unique, NOT NULL) - код МКБ (например, "J18.0")
- `title` (string, NOT NULL) - название заболевания
- `description` (text) - описание
- `embedding` (vector[768]) - **векторное представление для поиска**
- `source_file` (string) - файл-источник из data_mkb/

**`protocols`** (Протоколы МЗ РК)
- `title` (string, NOT NULL) - название протокола
- `code` (string) - код протокола
- `content` (text, NOT NULL) - содержимое протокола
- `embedding` (vector[768]) - **векторное представление для поиска**
- `source_file` (string) - файл-источник из data_protocol/

**Vector Search:** Используется pgvector extension с cosine distance метрикой.

### 3.5 Индексы

**Производительность критичные индексы:**
- `mkbs.code` (UNIQUE) - быстрый поиск по коду МКБ
- `mkbs.title` - поиск по названию
- `protocols.title` - поиск по названию протокола
- `verified_advisory_sheets.status` - фильтрация по статусу (red/yellow/green)
- `*.embedding` (pgvector) - векторный поиск по cosine similarity

**Devise индексы:** email, reset_password_token, confirmation_token (UNIQUE на всех user таблицах)

### 3.6 Диаграмма ER (упрощенная)

```
         AUTHENTICATION
         ──────────────
      ┌─────┐  ┌─────┐  ┌─────┐
      │ Aud │  │ MD  │  │ Doc │  (Devise users)
      └──┬──┘  └─────┘  └──┬──┘
         │                 │
         │ has_many        │ belongs_to
         │                 │
         ↓                 ↓
    ┌────────┐        ┌────────┐
    │ NotVer │        │MainDoc │
    └────┬───┘        └────────┘
         │
         │ (verification job)
         ↓
    ┌────────┐
    │Verified│  status: 🔴/🟡/🟢
    └────────┘

         KNOWLEDGE BASE
         ──────────────
    ┌─────┐      ┌──────────┐
    │ Mkb │      │ Protocol │
    └─────┘      └──────────┘
       ↓              ↓
    [embedding]   [embedding]
       768d          768d
       ↓              ↓
    ┌──────────────────────┐
    │   pgvector search    │
    │ (cosine similarity)  │
    └──────────────────────┘
```

---

## 4. API

### 4.1 Обзор

**Тип API:** REST (частично) + Rails MVC (HTML responses)
**Аутентификация:** Devise (session-based), отдельные скопы для каждой роли
**Формат ответов:** HTML (основной), JSON (опционально для AJAX)

### 4.2 Публичные маршруты

| Метод | Путь | Контроллер#действие | Описание |
|-------|------|---------------------|----------|
| GET | `/` | home#index | Главная страница |
| GET | `/up` | rails/health#show | Health check endpoint |

### 4.3 Аутентификация (Devise)

#### Auditors (Аудиторы)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/cabinet/auditors/login` | Страница входа |
| POST | `/cabinet/auditors/login` | Аутентификация |
| DELETE | `/cabinet/auditors/logout` | Выход |
| GET | `/cabinet/auditors/sign_up` | Регистрация (если включена) |
| POST | `/cabinet/auditors/password` | Восстановление пароля |

#### Main Doctors (Главные врачи)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/cabinet/main_doctors/login` | Страница входа |
| POST | `/cabinet/main_doctors/login` | Аутентификация |
| DELETE | `/cabinet/main_doctors/logout` | Выход |

#### Doctors (Врачи)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/cabinet/doctors/login` | Страница входа |
| POST | `/cabinet/doctors/login` | Аутентификация |
| DELETE | `/cabinet/doctors/logout` | Выход |

### 4.4 Аудитор (требуется авторизация)

| Метод | Путь | Контроллер#действие | Описание |
|-------|------|---------------------|----------|
| GET | `/cabinet/auditors/dashboard` | cabinet/auditors/dashboard#index | Дашборд аудитора |
| GET | `/cabinet/auditors/advisory_sheets` | cabinet/auditors/advisory_sheets#index | Список КЛ |
| GET | `/cabinet/auditors/advisory_sheets/upload` | cabinet/auditors/advisory_sheets#upload | Форма загрузки файлов |
| POST | `/cabinet/auditors/advisory_sheets` | cabinet/auditors/advisory_sheets#create | Загрузка КЛ (multipart/form-data) |
| GET | `/cabinet/auditors/advisory_sheets/:id` | cabinet/auditors/advisory_sheets#show | Просмотр КЛ |

**Пример запроса загрузки файлов:**

```http
POST /cabinet/auditors/advisory_sheets
Content-Type: multipart/form-data

files[]: <file1.pdf>
files[]: <file2.docx>
```

**Ответ:** Redirect на `/cabinet/auditors/advisory_sheets` с flash сообщением.

### 4.5 Главный врач / Врач (требуется авторизация)

| Метод | Путь | Контроллер#действие | Описание |
|-------|------|---------------------|----------|
| GET | `/cabinet/main_doctors/dashboard` | cabinet/main_doctors/dashboard#index | Дашборд главврача |
| GET | `/cabinet/doctors/dashboard` | cabinet/doctors/dashboard#index | Дашборд врача |

### 4.6 Внешний API (Gemini)

**Система интегрируется с Google Gemini API:**

```ruby
# Эндпоинт: generativelanguage.googleapis.com
# Библиотека: RubyLLM gem (обертка)

# 1. Embeddings
POST https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent
Authorization: Bearer <GEMINI_API_KEY>
Content-Type: application/json

{
  "content": { "parts": [{ "text": "текст для embedding" }] }
}

Response: { "embedding": { "values": [0.1, 0.2, ..., 768 floats] } }

# 2. Chat (Verification)
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent
Authorization: Bearer <GEMINI_API_KEY>
Content-Type: application/json

{
  "contents": [{ "role": "user", "parts": [{ "text": "prompt" }] }],
  "generationConfig": { "temperature": 0.1 }
}

Response: { "candidates": [{ "content": { "parts": [{ "text": "JSON response" }] } }] }
```

**Используется в:**
- `GeminiService.generate_embedding` - создание векторов
- `GeminiService.verify_advisory_sheet` - AI анализ КЛ

### 4.7 Обработка ошибок

**Rails стандартные обработчики:**
- 404 Not Found - страница не найдена
- 500 Internal Server Error - ошибка сервера
- 401 Unauthorized - требуется аутентификация (редирект на логин)
- 403 Forbidden - доступ запрещен

**Gemini API ошибки:**
```ruby
# В GeminiService реализован fallback:
rescue StandardError => e
  Rails.logger.error("GeminiService error: #{e.message}")
  { status: :yellow, result: "Ошибка проверки", recommendations: "" }
end
```

**Sidekiq Jobs:**
- Автоматический retry 3 раза с polynomial backoff
- Логирование ошибок в `log/sidekiq.log`

### 4.8 Мониторинг

**Development:**
- Sidekiq Web UI: http://localhost:3000/sidekiq
- Logs: `tail -f log/development.log`

**Production:**
- Mission Control Jobs (настраивается отдельно)
- Rails logs via `kamal app logs`

---

## 5. Инфраструктура

### 5.1 Хостинг и окружение

**Development (локально):**
- Rails server: `localhost:3000`
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- Sidekiq: процесс в фоне

**Production:**
- **Платформа:** Собственный сервер / VPS
- **Контейнеризация:** Docker (управление через Kamal)
- **Веб-сервер:** Thruster (HTTP/2 reverse proxy, Rails 8 default)
- **App server:** Puma (встроенный в Rails)
- **База данных:** PostgreSQL 17 (внешний сервер, не в контейнере)
- **Кэш/Очереди:** Redis (внешний сервер)
- **SSL:** Let's Encrypt (автоматическая настройка через Kamal)

**Тарифный план:** Не указан (зависит от выбранного провайдера VPS)

### 5.2 Процесс деплоя

**Инструмент:** Kamal (Docker-based deployment)
**Тип:** Автоматизированный через CLI команды

#### Первоначальная настройка

```bash
# 1. Заполнить config/deploy.yml
# Указать IP серверов, registry, domain

# 2. Создать секреты в .kamal/secrets
# RAILS_MASTER_KEY=...
# KAMAL_REGISTRY_PASSWORD=...
# DATABASE_PASSWORD=...

# 3. Setup сервера (устанавливает Docker, создает volume)
kamal setup
```

#### Стандартный деплой

```bash
# Полный деплой (build + push + deploy)
kamal deploy

# Последовательность:
# 1. Docker build образа
# 2. Push в registry (Docker Hub / custom)
# 3. Pull образа на серверах
# 4. Остановка старых контейнеров
# 5. Запуск новых контейнеров
# 6. Health check (GET /up)
# 7. Переключение трафика на новую версию
```

#### Мониторинг и управление

```bash
# Просмотр логов
kamal app logs -f

# Проверка статуса
kamal app details

# Rails console на продакшене
kamal app exec -i "bin/rails console"

# Database console
kamal app exec -i "bin/rails dbconsole"

# Перезапуск
kamal app restart

# Откат к предыдущей версии
kamal rollback
```

**Частота деплоя:** По требованию (ручной запуск `kamal deploy`)

### 5.3 Переменные окружения (Production)

**Секретные (в .kamal/secrets):**
```bash
RAILS_MASTER_KEY=<64-char-hex>      # Для credentials.yml.enc
GEMINI_API_KEY=<api-key>            # Google Gemini API
DATABASE_PASSWORD=<password>        # PostgreSQL пароль
KAMAL_REGISTRY_PASSWORD=<token>     # Docker registry
```

**Публичные (в config/deploy.yml → env.clear):**
```yaml
SOLID_QUEUE_IN_PUMA: true           # Запуск Solid Queue в Puma процессе
DB_HOST: 192.168.**.***               # Адрес PostgreSQL сервера
REDIS_URL: redis://192.168.***:**** # Адрес Redis
RAILS_LOG_LEVEL: info               # Уровень логирования
```

### 5.4 Резервное копирование

#### База данных PostgreSQL

**Метод:** pg_dump (ручной или через cron)

```bash
# Ежедневный бэкап (добавить в cron на DB сервере)
0 2 * * * pg_dump -U postgres -d medical_audit_production \
  -F c -f /backups/medical_audit_$(date +\%Y\%m\%d).dump

# Бэкап только схемы
pg_dump -U postgres -d medical_audit_production --schema-only \
  > schema_backup.sql

# Восстановление из бэкапа
pg_restore -U postgres -d medical_audit_production \
  /backups/medical_audit_20250101.dump
```

**Рекомендуемая стратегия:**
- Ежедневные бэкапы в 2:00 AM (local time)
- Хранение последних 7 дней (недельная ротация)
- Месячные бэкапы (первое число месяца) - хранить 12 месяцев
- Копирование критичных бэкапов на удаленное хранилище (S3/BackBlaze)

#### Файлы приложения

**Docker volumes (через Kamal):**
```yaml
# config/deploy.yml
volumes:
  - "medical_audit_storage:/rails/storage"  # ActiveStorage файлы
```

**Бэкап volume:**
```bash
# На сервере
docker run --rm \
  -v medical_audit_storage:/source \
  -v /backups:/backup \
  alpine tar czf /backup/storage_$(date +%Y%m%d).tar.gz -C /source .

# Восстановление
docker run --rm \
  -v medical_audit_storage:/target \
  -v /backups:/backup \
  alpine tar xzf /backup/storage_20250101.tar.gz -C /target
```

#### Автоматизация бэкапов

**Настройка cron на сервере БД:**
```bash
# /etc/cron.d/medical_audit_backups
0 2 * * * postgres /scripts/backup_medical_audit.sh
0 3 1 * * postgres /scripts/monthly_backup.sh
```

**Пример скрипта `backup_medical_audit.sh`:**
```bash
#!/bin/bash
BACKUP_DIR="/backups/daily"
DATE=$(date +%Y%m%d)
KEEP_DAYS=7

# Создать бэкап
pg_dump -U postgres -d medical_audit_production \
  -F c -f $BACKUP_DIR/db_$DATE.dump

# Удалить старые бэкапы (>7 дней)
find $BACKUP_DIR -name "db_*.dump" -mtime +$KEEP_DAYS -delete

# Загрузить на S3 (опционально)
# aws s3 cp $BACKUP_DIR/db_$DATE.dump s3://bucket/backups/
```

**Что бэкапить:**
1. ✅ **PostgreSQL база данных** (ежедневно)
2. ✅ **Docker volume** `/rails/storage` (если используется ActiveStorage)
3. ✅ **Конфиг файлы** `config/`, `.kamal/secrets` (при изменениях)
4. ⚪ **Код приложения** (хранится в Git, не критично)
5. ⚪ **Gem'ы** (восстанавливаются через `bundle install`)

### 5.5 Мониторинг и алерты

**Встроенные инструменты:**
- Health check endpoint: `GET /up` (проверяется Kamal после деплоя)
- Sidekiq monitoring: Mission Control Jobs (настраивается отдельно)
- Bullet (N+1 queries) - только development

### 5.6 Масштабирование

**Текущая конфигурация:** Single server (монолит)

**Горизонтальное масштабирование (при росте нагрузки):**
```yaml
# config/deploy.yml
servers:
  web:
    - 192.168.0.1
    - 192.168.0.2  # Добавить второй веб-сервер
    - 192.168.0.3  # Третий сервер
  job:
    hosts:
      - 192.168.0.4  # Отдельный сервер для Sidekiq jobs
    cmd: bin/jobs
```

**Load balancer:** Настраивается отдельно (Nginx, HAProxy, CloudFlare)

---

## 6. Сторонние библиотеки и сервисы

### 6.1 Backend зависимости (Ruby gems)

| Gem | Версия | Назначение | Лицензия | Стоимость |
|-----|--------|-----------|----------|-----------|
| **rails** | 8.0.4 | Web framework | MIT | ✅ Бесплатно |
| **pg** | ~1.5 | PostgreSQL adapter | BSD | ✅ Бесплатно |
| **puma** | ~7.1 | Web server | BSD | ✅ Бесплатно |
| **devise** | ~4.9 | Authentication | MIT | ✅ Бесплатно |
| **devise-i18n** | ~1.12 | Devise локализация | MIT | ✅ Бесплатно |

#### AI & RAG

| Gem | Версия | Назначение | Документация |
|-----|--------|-----------|--------------|
| **ruby_llm** | 1.9.1 | Unified AI interface | [Docs](https://github.com/ruby-llm/ruby_llm) |
| **neighbor** | latest | pgvector integration | [Docs](https://github.com/ankane/neighbor) |
| **tiktoken_ruby** | latest | Token counting | [Docs](https://github.com/IAPark/tiktoken_ruby) |

#### File Processing

| Gem | Версия | Форматы | Документация |
|-----|--------|---------|--------------|
| **pdf-reader** | latest | PDF | [Docs](https://github.com/yob/pdf-reader) |
| **docx** | latest | DOCX | [Docs](https://github.com/ruby-docx/docx) |
| **roo** | ~3.0.0 | XLS/XLSX/CSV | [Docs](https://github.com/roo-rb/roo) |
| **ruby-vips** | latest | Image processing | [Docs](https://github.com/libvips/ruby-vips) |

#### Background Jobs & Scheduling

| Gem | Версия | Назначение | Документация |
|-----|--------|-----------|--------------|
| **sidekiq** | ~8.0 | Background jobs | [Docs](https://github.com/sidekiq/sidekiq) |
| **redis** | ~5.4 | Sidekiq backend | [Docs](https://github.com/redis/redis-rb) |
| **solid_queue** | latest | ActiveJob backend (Rails 8) | [Docs](https://github.com/rails/solid_queue) |
| **solid_cache** | latest | DB-backed cache (Rails 8) | [Docs](https://github.com/rails/solid_cache) |
| **solid_cable** | latest | WebSocket (Rails 8) | [Docs](https://github.com/rails/solid_cable) |
| **whenever** | ~1.1 | Cron job DSL | [Docs](https://github.com/javan/whenever) |
| **mission_control-jobs** | latest | Job monitoring UI | [Docs](https://github.com/basecamp/mission_control-jobs) |

#### Frontend & Assets

| Gem | Версия | Назначение | Документация |
|-----|--------|-----------|--------------|
| **tailwindcss-rails** | ~4.0 | Tailwind CSS integration | [Docs](https://github.com/rails/tailwindcss-rails) |
| **propshaft** | latest | Asset pipeline (Rails 8) | [Docs](https://github.com/rails/propshaft) |
| **importmap-rails** | latest | ES Modules без сборки | [Docs](https://github.com/rails/importmap-rails) |
| **turbo-rails** | latest | Hotwire Turbo | [Docs](https://turbo.hotwired.dev/) |
| **stimulus-rails** | latest | Hotwire Stimulus | [Docs](https://stimulus.hotwired.dev/) |

#### Development & Testing

| Gem | Версия | Назначение | Только Dev/Test |
|-----|--------|-----------|-----------------|
| **rspec-rails** | ~8.0.0 | Testing framework | ✅ |
| **factory_bot_rails** | ~6.5 | Test data factories | ✅ |
| **faker** | latest | Fake data generator | ✅ |
| **capybara** | ~3.40 | Integration testing | ✅ |
| **selenium-webdriver** | ~4.39 | Browser automation | ✅ |
| **database_cleaner-active_record** | ~2.2 | Test DB cleanup | ✅ |
| **shoulda-matchers** | ~7.0 | RSpec matchers | ✅ |
| **rubocop-rails-omakase** | latest | Linter (Rails style) | ✅ |
| **brakeman** | latest | Security scanner | ✅ |
| **annotate** | latest | Schema comments | ✅ dev |
| **bullet** | latest | N+1 queries detection | ✅ dev |
| **letter_opener** | ~1.10 | Email preview | ✅ dev |
| **web-console** | latest | In-browser console | ✅ dev |
| **debug** | latest | Debugger | ✅ |
| **dotenv-rails** | latest | .env file loader | ✅ |

#### Deployment

| Gem | Версия | Назначение | Документация |
|-----|--------|-----------|--------------|
| **kamal** | latest | Docker deployment | [Docs](https://kamal-deploy.org/) |
| **thruster** | latest | HTTP/2 proxy | [Docs](https://github.com/basecamp/thruster) |

### 6.2 Внешние сервисы

| Сервис | Назначение | Тарификация | API Key |
|--------|-----------|-------------|---------|
| **Google Gemini API** | AI embeddings + chat | Pay-per-use | ✅ Требуется |
| **PostgreSQL 17** | Основная БД | Самохостинг / VPS | - |
| **Redis** | Sidekiq queue + cache | Самохостинг / VPS | - |
| **Docker Registry** | Хранение образов | Docker Hub (free tier) | ✅ Требуется |
| **Let's Encrypt** | SSL сертификаты | ✅ Бесплатно | Автоматически |

### 6.3 Платные зависимости

> ✅ **В проекте НЕТ платных обязательных зависимостей.**

**Потенциальные расходы (опционально):**
- Google Gemini API - pay-per-use (платно при превышении лимитов)
  - Бесплатный лимит: 15 requests/min, 1500 requests/day
  - Цены: [ai.google.dev/pricing](https://ai.google.dev/pricing)
- VPS хостинг (от 14 000 тг/мес, зависит от провайдера)
- Мониторинг сервисы (Sentry, New Relic - опционально)

### 6.4 JavaScript зависимости (через importmap)

```json
// config/importmap.rb содержит:
{
  "@hotwired/turbo-rails": "turbo.js",
  "@hotwired/stimulus": "stimulus.js",
  "@hotwired/stimulus-loading": "stimulus-loading.js"
}
```

**Node.js используется только для:**
- Tailwind CSS компиляция (`rails tailwindcss:build`)
- Все остальное через importmap (без npm/webpack/vite)

---

### Планируемые улучшения
- [ ] Добавить JSON API endpoints для мобильного приложения
- [ ] Настроить Mission Control Jobs
- [ ] Реализовать экспорт отчетов в PDF
- [ ] Добавить статистику и дашборды для главврача
- [ ] Настроить error tracking (Sentry)


**Документация:**
- Комментарии в коде (RuboCop enforces documentation)

**Последнее обновление:** 2025-12-11
**Версия документации:** 1.0.0
