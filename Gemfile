source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 7.1"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails", "~> 8.0.0"
  gem "factory_bot_rails", "~> 6.5", ">= 6.5.1"
  gem "faker"
  gem "dotenv-rails"
  gem "capybara", "~> 3.40"
  gem "launchy", "~> 3.1"
  gem "selenium-webdriver", "~> 4.39"
  gem "database_cleaner-active_record", "~> 2.2"
  gem "shoulda-matchers", "~> 7.0"
  gem "letter_opener", "~> 1.10"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "annotate"
  gem "bullet" # N+1 queries detection
end

# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails", "~> 4.0" # which transitively pins tailwindcss-ruby to v4

# AI & RAG
gem "ruby_llm"
gem "neighbor" # pgvector for embeddings
gem "tiktoken_ruby" # Token counting

# File processing
gem "ruby-vips" # Image processing
gem "pdf-reader" # PDF parsing
gem "docx" # DOCX parsing
gem "roo", "~> 3.0.0" # Excel parsing

# Search indexis ibject from find object to form [https://github.com/pat/thinking-sphinx]
gem "mysql2",          "~> 0.4",    platform: :ruby
gem "jdbc-mysql",      "~> 5.1.35", platform: :jruby
gem "thinking-sphinx", "~> 5.5"

# Scheduling cron & jobs
gem "whenever", "~> 1.1"
gem "sidekiq", "~> 8.0"
gem "redis", "~> 5.4", ">= 5.4.1"

# Background jobs control + interface
gem "mission_control-jobs" # Job monitoring UI

# monitor add migration table
#gem "strong_migrations", "~> 2.5"

# Authenticate build [https://github.com/heartcombo/devise]
gem "devise-i18n", "~> 1.12"
gem "devise", "~> 4.9"

# Omit the patch segment to avoid breaking changes
gem "kaminari"
