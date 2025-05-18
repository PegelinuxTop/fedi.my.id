# frozen_string_literal: true

class RemoveQuoteIdFromStatuses < ActiveRecord::Migration[8.0]
  def change
    remove_index :statuses, :quote_id, if_exists: true
    remove_column :statuses, :quote_id, :bigint, if_exists: true
  end
end
