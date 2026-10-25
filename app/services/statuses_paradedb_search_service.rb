# frozen_string_literal: true

class StatusesParadedbSearchService < BaseService
  def call(query, account = nil, options = {})
    MastodonOTELTracer.in_span('StatusesParadedbSearchService#call') do |span|
      @query   = query&.strip
      @account = account
      @options = options
      @limit   = options[:limit].to_i
      @offset  = options[:offset].to_i

      span.add_attributes(
        'search.offset' => @offset,
        'search.limit' => @limit,
        'search.backend' => 'paradedb'
      )

      status_search_results.tap do |results|
        span.set_attribute('search.results.count', results.size)
      end
    end
  end

  private

  def status_search_results
    parsed_ast = SearchQueryParser.new.parse(@query) rescue nil
    return [] if parsed_ast.nil?

    query_builder = ParadedbQueryTransformer.new.parse(parsed_ast, current_account: @account)

    doc_ids = query_builder.build_relation
                           .order(status_id: :desc)
                           .limit(@limit)
                           .offset(@offset)
                           .pluck(:status_id)

    return [] if doc_ids.empty?

    statuses = Status.where(id: doc_ids)
                     .includes(:account, :media_attachments, :preloadable_poll)
                     .index_by(&:id)

    results = doc_ids.map { |id| statuses[id] }.compact

    account_ids     = results.map(&:account_id)
    account_domains = results.map(&:account_domain)
    @account.preload_relations!(account_ids, account_domains) if @account

    results.reject { |status| StatusFilter.new(status, @account).filtered? }
  rescue => e
    Rails.logger.warn "ParadeDB status search failed: #{e.message}"
    []
  end
end
