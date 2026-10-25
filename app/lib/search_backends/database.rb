# frozen_string_literal: true

module SearchBackends
  class Database < Base
    def statuses_searchable?(_account)
      false
    end

    def search_statuses(_query, _account, _options = {})
      []
    end

    def search_accounts(query, account, options = {})
      AccountSearchService.new.call(query, account, options)
    end

    def search_tags(query, options = {})
      TagSearchService.new.call(query, options)
    end
  end
end
