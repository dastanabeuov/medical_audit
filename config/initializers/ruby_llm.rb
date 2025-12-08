RubyLLM.configure do |config|
  config.providers = {
    openai: {
      api_key: ENV["OPENAI_API_KEY"],
      default_model: "gpt-4o-mini", # Для быстрых операций
    },
    anthropic: {
      api_key: ENV["ANTHROPIC_API_KEY"],
      default_model: "claude-sonnet-4-20250514", # Основная модель для анализа
    }
  }
end
