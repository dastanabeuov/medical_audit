# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Medical Audit System - AI-powered Rails 8 application for automated auditing of medical consultation sheets (advisory sheets) against ICD-10/11 and Kazakhstan Ministry of Health protocols using RAG (Retrieval-Augmented Generation).

**Core Functionality:**
- Batch upload and processing of 100+ medical consultation sheets
- AI-powered verification against knowledge base (ICD codes + protocols)
- Risk scoring (0-100) with color classification: Red (<50), Yellow (50-80), Green (80+)
- RAG pipeline using vector search (pgvector) and semantic matching

## Development Commands

### Setup
```bash
# Install dependencies
bundle install

# Setup database (requires PostgreSQL with pgvector extension)
rails db:setup

# Run migrations
rails db:migrate

# Start development server with Tailwind CSS watcher
bin/dev
```

### Testing
```bash
# Setup test database
RAILS_ENV=test rails db:setup

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/verified_advisory_sheet_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Code Quality
```bash
# Run RuboCop (uses rubocop-rails-omakase)
bundle exec rubocop

# Auto-fix violations
bundle exec rubocop -a

# Security audit
bundle exec brakeman
```

### Background Jobs
```bash
# Access Sidekiq web UI (development only)
# Visit http://localhost:3000/sidekiq

# Access Mission Control Jobs UI
# Configure and visit jobs monitoring interface
```

### Database Console
```bash
# Rails console
rails console

# Database console
rails dbconsole
```

### Knowledge Base Management
```bash
# Import ICD codes from data_mkb/
rails console
> MkbImportService.import_from_directory("data_mkb")

# Import protocols from data_protocol/
> ProtocolImportService.import_from_directory("data_protocol")

# Via background job
> ImportKnowledgeBaseJob.perform_later

# Vector search testing in console
> query_embedding = GeminiService.generate_embedding("артериальная гипертензия")
> Protocol.search_similar(query_embedding, limit: 5)
> Mkb.search_similar(query_embedding, limit: 10)
```

### Doctor Import from Medelement
```bash
# Test connection and fetch specialists (without saving)
rails doctors:test_fetch_specialists

# Import all specialists from medelement.com
rails doctors:import_from_medelement

# Import with attachment to main doctor
rails doctors:import_with_main_doctor[main_doctor@example.com]

# In Rails console
> specialists = MedelementScraperService.fetch_all_specialists
> result = DoctorImportService.import_from_medelement
> # => { created: 15, updated: 5, failed: 0, errors: [] }

# Required ENV variables in .env:
# MEDELEMENT_LOGIN=your_email@example.com
# MEDELEMENT_PASSWORD=your_password
```

See `MEDELEMENT_IMPORT.md` for detailed documentation.

**Current Status (2025-12-27):**
- ⚠️ Medelement.com uses JavaScript/AJAX for loading specialists data
- Net::HTTP version implemented but requires AJAX endpoint discovery
- See `QUICK_START_AJAX.md` for endpoint discovery instructions
- See `AJAX_INTEGRATION_PLAN.md` for integration roadmap
- Alternative: Use original Selenium version (works but requires browser automation)

## Architecture

### RAG Pipeline Architecture

The system implements a hybrid RAG approach combining vector similarity search with keyword matching:

1. **Document Ingestion** (`MkbImportService`, `ProtocolImportService`)
   - Parse ICD codes and protocols from source files (data_mkb/, data_protocol/)
   - Generate embeddings using Gemini text-embedding-004 (768 dimensions)
   - Store in PostgreSQL with pgvector extension

2. **Advisory Sheet Processing** (`AdvisorySheetUploadService`)
   - Upload files (PDF, DOCX, TXT) via drag-and-drop interface
   - Parse and extract text using FileParserService
   - Create NotVerifiedAdvisorySheet records
   - Queue verification jobs (Sidekiq)

3. **Verification Pipeline** (`AdvisorySheetVerificationService`)
   - **Sanitization**: Remove personal data (PersonalDataSanitizerService)
     - Removes: full names, IINs (Kazakhstan ID numbers), phone numbers, birth dates, addresses, workplaces
     - Extracts only medical content (diagnosis, treatment, examinations)
   - **Embedding Generation**: Create query embedding from sanitized content
   - **Hybrid Retrieval**:
     - Vector similarity search using cosine distance (Neighbor gem)
     - Text-based keyword matching for ICD codes and medical terms
     - Combine results: top 5 protocols + top 10 ICD codes
   - **AI Analysis**: GeminiService verifies against retrieved context
     - Prompt includes protocol/ICD context + sanitized content
     - Returns structured JSON response
     - Temperature: 0.1 for consistency
   - **Scoring**: Returns status (red/yellow/green) + detailed recommendations
   - **Persistence**: Creates VerifiedAdvisorySheet, destroys NotVerifiedAdvisorySheet on success

4. **Models with Vector Search**
   - `Mkb`: ICD codes with embeddings, implements `search_similar(query_embedding, limit:)`
   - `Protocol`: Medical protocols with embeddings, implements `search_similar(query_embedding, limit:)`
   - Both use `has_neighbors :embedding` (Neighbor gem) for vector operations

### Authentication System

Three separate Devise scopes with namespaced routes and controllers:

- **Auditors**: Upload and verify advisory sheets (`cabinet/auditors/`)
- **Main Doctors**: Department heads with oversight (`cabinet/main_doctors/`)
- **Doctors**: Individual practitioners (`cabinet/doctors/`)

Login paths:
- `/cabinet/auditors/login`
- `/cabinet/main_doctors/login`
- `/cabinet/doctors/login`

### Service Layer Pattern

Services are the primary business logic layer:

- **AdvisorySheetUploadService**: File upload and batch creation
  - Extracts recording numbers via regex pattern
  - Validates file formats before processing
- **AdvisorySheetVerificationService**: Core RAG verification logic
  - 5-step pipeline: sanitize → embed → retrieve → verify → save
  - Returns hash: `{ success: true/false, error: nil, verified_sheet: ... }`
- **GeminiService**: AI client wrapper (embeddings + chat completion)
  - Handles API failures with fallback responses
  - Truncates text to 8000 chars for embedding API
  - Parses JSON from AI responses with error handling
- **PersonalDataSanitizerService**: Extract medical content, remove PII
  - Regex-based pattern matching for Kazakh ID numbers (IIN), phone numbers, etc.
  - GDPR/privacy-focused data masking
- **FileParserService**: Multi-format document parsing (PDF/DOCX/TXT)
  - Uses: pdf-reader (PDF), docx (DOCX), roo (XLS/XLSX)
  - Handles temporary file creation/cleanup
- **MkbImportService**: Bulk import ICD codes with embeddings
  - Parses files from data_mkb/ directory
  - Generates embeddings for each code, bulk upserts
- **ProtocolImportService**: Bulk import protocols with embeddings
  - Parses files from data_protocol/ directory
  - Generates embeddings, bulk upserts
- **MedelementScraperService**: Web scraping врачей с medelement.com
  - Current implementation: Net::HTTP with AJAX endpoint support (in progress)
  - Features: authentication, redirect handling, gzip decoding, retry logic
  - Authenticates through https://login.medelement.com/
  - Status: Requires AJAX endpoint discovery (see QUICK_START_AJAX.md)
  - Methods: `find_doctor(doctor_name)`, `fetch_all_specialists()`
  - Fallback: Selenium WebDriver version available (browser automation)
- **DoctorImportService**: Import врачей from medelement data
  - Creates or updates Doctor records by email
  - Generates temporary passwords for new doctors
  - Skips email confirmation for imported accounts
  - Returns import stats: `{ created:, updated:, failed:, errors: [] }`

### Job Processing

Uses Sidekiq for async processing:

- **VerifyAdvisorySheetJob**: Single sheet verification
- **VerifyAllAdvisorySheetsJob**: Batch processing all pending sheets
- **ImportKnowledgeBaseJob**: Knowledge base import/reindexing

Rails 8 Solid Queue is configured but not actively used (commented in Procfile.dev).

### Database Schema Notes

**Vector Storage:**
- `mkbs.embedding`: vector(768) - ICD code embeddings
- `protocols.embedding`: vector(768) - Protocol embeddings
- Both indexed for fast cosine similarity search via pgvector

**Advisory Sheet Workflow:**
1. Upload → `not_verified_advisory_sheets` (pending verification)
2. Verification → `verified_advisory_sheets` (with status/results)
3. Original record destroyed after successful verification

**Status Enum** (VerifiedAdvisorySheet):
- 0: red (critical violations)
- 1: yellow (minor issues)
- 2: green (compliant)

**Key Model Relationships:**
- `Auditor` has_many `:not_verified_advisory_sheets`, `:verified_advisory_sheets`
- `MainDoctor` has_many `:doctors`
- `Doctor` belongs_to `:main_doctor` (optional)
- All three user models use separate Devise scopes with independent authentication

### AI Integration

**RubyLLM Gem** (v1.9.1): Unified interface for multiple AI providers
- Configuration in `config/initializers/ruby_llm.rb`

**Primary Model**: Gemini 2.0 Flash (gemini-2.0-flash-001)
- Verification prompts with protocol/ICD context
- Structured JSON responses
- Temperature: 0.1 for consistency

**Embeddings**: text-embedding-004 (768d)
- Vector dimensions: 768
- Used for both documents and query vectors
- Cosine distance for similarity search

**Usage Pattern:**
```ruby
# Embeddings (returns RubyLLM::Embedding)
embedding = RubyLLM.embed("text", model: "text-embedding-004")
vector = embedding.vectors  # Array of 768 floats

# Chat (returns RubyLLM::Message)
chat = RubyLLM.chat(model: "gemini-2.0-flash-001")
response = chat.ask("prompt")
content = response.content  # String
```

**Environment Variables Required:**
- `GEMINI_API_KEY`: Gemini API access (configured in ruby_llm initializer)
- `DATABASE_PASSWORD`: PostgreSQL credentials

### Frontend Stack

- **Tailwind CSS 4**: Utility-first styling (tailwindcss-rails gem)
- **Stimulus**: JavaScript framework for interactions
- **Turbo**: SPA-like navigation
- **ActionCable**: Real-time updates (via Solid Cable in production)

## Common Patterns

### Creating and Verifying Advisory Sheets

```ruby
# In controller or service
sheet = NotVerifiedAdvisorySheet.create!(
  recording: unique_identifier,
  body: extracted_text,
  auditor: current_auditor,
  original_filename: file.original_filename
)

# Queue verification job
VerifyAdvisorySheetJob.perform_later(sheet.id)

# Or synchronous verification
verified = AdvisorySheetVerificationService.verify(sheet)
```

### Vector Search Pattern

```ruby
# Generate embedding for query
query_embedding = GeminiService.generate_embedding(search_text)

# Find similar documents
similar_protocols = Protocol.search_similar(query_embedding, limit: 5)
similar_mkbs = Mkb.search_similar(query_embedding, limit: 10)

# Hybrid search (vector + text)
vector_results = Protocol.search_similar(embedding, limit: 3)
text_results = Protocol.search_by_text("артериальная гипертензия").limit(2)
combined = (vector_results + text_results).uniq
```

### Importing Knowledge Base

```ruby
# Import ICD codes from data_mkb/
MkbImportService.import_from_directory("data_mkb")

# Import protocols from data_protocol/
ProtocolImportService.import_from_directory("data_protocol")

# Via background job
ImportKnowledgeBaseJob.perform_later
```

## Important Constraints

1. **Personal Data Protection**: Always use PersonalDataSanitizerService before sending to AI
2. **Embedding Dimensions**: Must match 768 (text-embedding-004 output size)
3. **PostgreSQL Extension**: Requires pgvector extension enabled
4. **File Upload Limits**: Consider implementing size limits for batch uploads
5. **AI Rate Limits**: GeminiService includes error handling for API failures

## Testing Approach

- **RSpec**: Primary testing framework
- **FactoryBot**: Test data generation
- **Shoulda Matchers**: Model validation testing
- **Database Cleaner**: Test isolation
- **Capybara + Selenium**: System/integration tests

Test files mirror app structure:
- `spec/models/` - Model specs
- `spec/services/` - Service specs (critical for RAG logic)
- `spec/jobs/` - Job specs
- `spec/system/` - End-to-end tests

## Deployment

**Kamal** (Docker-based deployment) configured in `config/deploy.yml`:

```bash
# Deploy to production
kamal deploy

# Check app status
kamal app details

# View logs
kamal app logs

# Rails console on server
kamal app exec -i "bin/rails console"

# Database console on server
kamal app exec -i "bin/rails dbconsole"

# Restart app
kamal app restart

# Rollback to previous version
kamal rollback
```

**Architecture:**
- **Thruster**: HTTP/2 reverse proxy (Rails 8 default)
- **Production Databases**: Separate DBs for primary, cache, queue, cable
- **SSL**: Auto-provisioning via Let's Encrypt
- **Volumes**: Persistent storage at `/rails/storage`
- **Environment**: RAILS_MASTER_KEY and DATABASE credentials required
