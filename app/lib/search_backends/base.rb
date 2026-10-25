# frozen_string_literal: true

module SearchBackends
  class Base
    def statuses_searchable?(account)
      raise NotImplementedError
    end

    def search_statuses(query, account, options = {})
      raise NotImplementedError
    end

    def search_accounts(query, account, options = {})
      raise NotImplementedError
    end

    def search_tags(query, options = {})
      raise NotImplementedError
    end
  end
end
