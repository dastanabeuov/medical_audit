class RagRetrieverService
  def initialize(query, filters: {})
    @query = query
    @filters = filters
  end

  def retrieve(limit: 5)
    # Гибридный поиск: векторный + ключевые слова
    vector_results = vector_search(limit: limit * 2)
    keyword_results = keyword_search(limit: limit)

    # Объединяем и ранжируем результаты
    combined = combine_and_rerank(vector_results, keyword_results)

    combined.take(limit)
  end

  def retrieve_context_window(limit: 5, max_tokens: 6000)
    results = retrieve(limit: limit)

    # Формируем контекст с учетом лимита токенов
    build_context(results, max_tokens: max_tokens)
  end

  private

  def vector_search(limit:)
    base_query = KnowledgeDocument.where.not(parent_document_id: nil)
    base_query = apply_filters(base_query)

    base_query.search(@query, limit: limit)
  end

  def keyword_search(limit:)
    base_query = KnowledgeDocument.where.not(parent_document_id: nil)
    base_query = apply_filters(base_query)

    base_query
      .where("content ILIKE ?", "%#{@query}%")
      .or(base_query.where("title ILIKE ?", "%#{@query}%"))
      .limit(limit)
  end

  def apply_filters(query)
    if @filters[:document_type].present?
      query = query.where(document_type: @filters[:document_type])
    end

    if @filters[:source].present?
      query = query.where(source: @filters[:source])
    end

    query
  end

  def combine_and_rerank(vector_results, keyword_results)
    # Простое объединение с удалением дубликатов
    all_results = (vector_results + keyword_results).uniq(&:id)

    # Сортируем по релевантности (можно улучшить)
    all_results.sort_by do |doc|
      vector_score = vector_results.index(doc) || 999
      keyword_score = keyword_results.index(doc) || 999

      # Чем меньше, тем лучше
      [vector_score, keyword_score].min
    end
  end

  def build_context(documents, max_tokens:)
    encoder = Tiktoken.encoding_for_model("gpt-4")
    context_parts = []
    total_tokens = 0

    documents.each do |doc|
      content = format_document(doc)
      tokens = encoder.encode(content).length

      break if total_tokens + tokens > max_tokens

      context_parts << content
      total_tokens += tokens
    end

    context_parts.join("\n\n---\n\n")
  end

  def format_document(doc)
    <<~TEXT
      Источник: #{doc.source}
      Тип: #{doc.document_type}
      Заголовок: #{doc.title}

      #{doc.content}
    TEXT
  end
end
