# frozen_string_literal: true

module SearchBackend
  class << self
    def current
      @current ||= begin
        backend_name = ENV.fetch('SEARCH_BACKEND') do
          Chewy.enabled? ? 'elasticsearch' : 'database'
        end.downcase

        case backend_name
        when 'paradedb'
          SearchBackends::Paradedb.new
        when 'elasticsearch', 'chewy', 'es'
          SearchBackends::Elasticsearch.new
        else
          SearchBackends::Database.new
        end
      end
    end

    # Reset cached backend (useful in testing)
    def reset!
      @current = nil
    end

    def search_enabled?
      !database? && (paradedb? || Chewy.enabled?)
    end

    def paradedb?
      current.is_a?(SearchBackends::Paradedb)
    end

    def elasticsearch?
      current.is_a?(SearchBackends::Elasticsearch)
    end

    def database?
      current.is_a?(SearchBackends::Database)
    end

    def dual_write?
      ENV['SEARCH_DUAL_WRITE'] == 'true'
    end
  end
end
