# frozen_string_literal: true

class ParadedbQueryTransformer
  SUPPORTED_PREFIXES = %w(
    has
    is
    language
    from
    before
    after
    during
    in
  ).freeze

  class Query
    attr_reader :clauses, :options

    def initialize(clauses, options = {})
      @clauses = clauses
      @options = options
    end

    def build_relation
      relation = StatusSearchDocument.all

      clauses_by_operator = @clauses.compact.group_by(&:operator)
      must_clauses = clauses_by_operator.fetch(:must, [])
      must_not_clauses = clauses_by_operator.fetch(:must_not, [])
      filter_clauses = clauses_by_operator.fetch(:filter, [])
      flags = clauses_by_operator.fetch(:flag, []).to_h { |c| [c.prefix, c.term] }

      current_account = @options[:current_account]

      case flags['in']
      when 'library'
        relation = current_account ? relation.searchable_by_account(current_account.id) : relation.none
      when 'public'
        relation = relation.public_statuses
      else
        if current_account
          relation = relation.where(
            '(visibility = ? AND indexable = true) OR (searchable_by @> ARRAY[?]::bigint[])',
            Status.visibilities[:public],
            current_account.id
          )
        else
          relation = relation.public_statuses
        end
      end

      # BM25 Full text search terms
      terms = must_clauses.map(&:term).reject(&:blank?)
      if terms.any?
        if bm25_supported?
          bm25_terms = terms.map { |t| escape_bm25_term(t) }.reject(&:blank?)
          if bm25_terms.any?
            relation = relation.where('searchable_text @@@ ?', bm25_terms.join(' AND '))
          end
        else
          terms.each do |term|
            relation = relation.where('searchable_text ILIKE ?', "%#{sanitize_sql_like(term)}%")
          end
        end
      end

      must_not_terms = must_not_clauses.map(&:term).reject(&:blank?)
      if must_not_terms.any?
        if bm25_supported?
          bm25_not_terms = must_not_terms.map { |t| escape_bm25_term(t) }.reject(&:blank?)
          if bm25_not_terms.any?
            relation = relation.where('NOT (searchable_text @@@ ?)', bm25_not_terms.join(' OR '))
          end
        else
          must_not_terms.each do |term|
            relation = relation.where.not('searchable_text ILIKE ?', "%#{sanitize_sql_like(term)}%")
          end
        end
      end

      filter_clauses.each do |filter|
        relation = apply_filter(relation, filter)
      end

      relation
    end

    private

    def bm25_supported?
      @bm25_supported ||= begin
        StatusSearchDocument.connection.select_value("SELECT 1 FROM pg_am WHERE amname = 'bm25'").present?
      rescue
        false
      end
    end

    def sanitize_sql_like(string, escape_character = '\\')
      pattern = Regexp.union(escape_character, '%', '_')
      string.gsub(pattern) { |x| [escape_character, x].join }
    end

    def escape_bm25_term(term)
      term.gsub(/[^a-zA-Z0-9_\-\.\#]/, ' ').strip
    end

    def apply_filter(relation, filter)
      case filter.prefix
      when 'from'
        account_id = resolve_account_id(filter.term)
        filter.negated? ? relation.where.not(account_id: account_id) : relation.where(account_id: account_id)
      when 'language'
        filter.negated? ? relation.where.not(language: filter.term) : relation.where(language: filter.term)
      when 'has', 'is'
        filter.negated? ? relation.where('NOT (? = ANY(properties))', filter.term) : relation.where('? = ANY(properties)', filter.term)
      when 'before'
        date = parse_date(filter.term)
        relation.where('status_created_at < ?', date) if date
      when 'after'
        date = parse_date(filter.term)
        relation.where('status_created_at > ?', date) if date
      when 'during'
        date = parse_date(filter.term)
        relation.where(status_created_at: date.beginning_of_day..date.end_of_day) if date
      else
        relation
      end
    end

    def resolve_account_id(term)
      return @options[:current_account]&.id || -1 if term == 'me'

      username, domain = term.gsub(/\A@/, '').split('@')
      domain = nil if TagManager.instance.local_domain?(domain)
      account = Account.find_remote(username, domain)
      account&.id || -1
    end

    def parse_date(term)
      Time.zone.parse(term) rescue nil
    end
  end

  class Clause
    attr_reader :operator, :prefix, :term

    def initialize(operator, prefix, term, negated = false)
      @operator = operator
      @prefix   = prefix
      @term     = term
      @negated  = negated
    end

    def negated?
      @negated
    end
  end

  def parse(parsed_ast, current_account: nil)
    clauses = []

    if parsed_ast.is_a?(Hash) && parsed_ast[:query]
      items = parsed_ast[:query]
      items = [items] unless items.is_a?(Array)

      items.each do |item|
        clause_hash = item[:clause] || item
        next unless clause_hash.is_a?(Hash)

        op = clause_hash[:operator]&.to_s
        operator = op == '-' ? :must_not : :must

        if clause_hash[:prefix]
          prefix = clause_hash[:prefix][:term].to_s.downcase
          term = clause_hash[:phrase] ? clause_hash[:phrase].map { |t| t[:term].to_s }.join(' ') : clause_hash[:term].to_s

          if prefix == 'in'
            clauses << Clause.new(:flag, prefix, term)
          elsif SUPPORTED_PREFIXES.include?(prefix)
            clauses << Clause.new(:filter, prefix, term, op == '-')
          else
            clauses << Clause.new(operator, nil, "#{prefix} #{term}")
          end
        elsif clause_hash[:term]
          clauses << Clause.new(operator, nil, clause_hash[:term].to_s)
        elsif clause_hash[:phrase]
          clauses << Clause.new(operator, nil, clause_hash[:phrase].map { |t| t[:term].to_s }.join(' '))
        end
      end
    end

    Query.new(clauses, current_account: current_account)
  end
end
