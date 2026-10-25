# frozen_string_literal: true

module Status::SearchConcern
  extend ActiveSupport::Concern

  included do
    scope :indexable, -> { without_reblogs.public_visibility.joins(:account).where(account: { indexable: true }) }

    has_one :search_document, class_name: 'StatusSearchDocument', foreign_key: :status_id, inverse_of: :status, dependent: :destroy
    after_commit :sync_search_documents, on: [:create, :update]
    after_destroy_commit :remove_search_document
  end

  def sync_search_documents
    if SearchBackend.paradedb? || SearchBackend.dual_write?
      UpsertStatusSearchDocumentWorker.perform_async(id)
    end
  end

  def remove_search_document
    if SearchBackend.paradedb? || SearchBackend.dual_write?
      StatusSearchDocument.remove_for_status_id!(id)
    end
  end

  def searchable_by
    @searchable_by ||= begin
      ids = []

      ids << account_id if local?

      ids += local_mentioned.pluck(:id)
      ids += local_favorited.pluck(:id)
      ids += local_reblogged.pluck(:id)
      ids += local_bookmarked.pluck(:id)
      ids += preloadable_poll.local_voters.pluck(:id) if preloadable_poll.present?

      ids.uniq
    end
  end

  def searchable_text
    [
      spoiler_text,
      FormattingHelper.extract_status_plain_text(self),
      preloadable_poll&.options&.join("\n\n"),
      ordered_media_attachments.map(&:description).join("\n\n"),
    ].compact.join("\n\n")
  end

  def searchable_properties
    [].tap do |properties|
      properties << 'image' if ordered_media_attachments.any?(&:image?)
      properties << 'video' if ordered_media_attachments.any?(&:video?)
      properties << 'audio' if ordered_media_attachments.any?(&:audio?)
      properties << 'media' if with_media?
      properties << 'poll' if with_poll?
      properties << 'link' if with_preview_card?
      properties << 'embed' if preview_card&.video?
      properties << 'sensitive' if sensitive?
      properties << 'reply' if reply?
      properties << 'quote' if with_quote?
    end
  end
end
