# frozen_string_literal: true

module SearchBackends
  class Elasticsearch < Base
    def statuses_searchable?(account)
      Chewy.enabled? && account.present?
    end

    def search_statuses(query, account, options = {})
      StatusesSearchService.new.call(query, account, options)
    end

    def search_accounts(query, account, options = {})
      AccountSearchService.new.call(query, account, options)
    end

    def search_tags(query, options = {})
      TagSearchService.new.call(query, options)
    end
  end
end
