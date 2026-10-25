# frozen_string_literal: true

module SearchBackends
  class Paradedb < Base
    def statuses_searchable?(account)
      account.present?
    end

    def search_statuses(query, account, options = {})
      StatusesParadedbSearchService.new.call(query, account, options)
    end

    def search_accounts(query, account, options = {})
      AccountSearchService.new.call(query, account, options)
    end

    def search_tags(query, options = {})
      TagSearchService.new.call(query, options)
    end
  end
end
