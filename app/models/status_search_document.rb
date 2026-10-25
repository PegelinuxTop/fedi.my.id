# frozen_string_literal: true

class StatusSearchDocument < ApplicationRecord
  self.primary_key = :status_id

  if ENV['PARADEDB_DATABASE_URL'].present?
    establish_connection URI.parse(ENV['PARADEDB_DATABASE_URL']).to_s
  end

  belongs_to :status, inverse_of: :search_document, optional: true
  belongs_to :account

  scope :searchable_by_account, ->(account_id) {
    where('searchable_by @> ARRAY[?]::bigint[]', account_id)
  }

  scope :public_statuses, -> {
    where(visibility: Status.visibilities[:public], indexable: true)
  }

  def self.refresh_for_status!(status)
    return if status.reblog?

    # If status is deleted or marked discard, remove search document
    if status.discarded?
      remove_for_status_id!(status.id)
      return
    end

    doc = find_or_initialize_by(status_id: status.id)
    doc.account_id = status.account_id
    doc.account_domain = status.account&.domain
    doc.searchable_text = status.searchable_text
    doc.tags = status.tags.map(&:display_name)
    doc.language = status.language
    doc.visibility = Status.visibilities[status.visibility] || 0
    doc.indexable = status.account&.indexable? || false
    doc.properties = status.searchable_properties
    doc.searchable_by = status.searchable_by
    doc.status_created_at = status.created_at
    doc.save!
  end

  def self.remove_for_status_id!(status_id)
    where(status_id: status_id).delete_all
  end
end
