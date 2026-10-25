# frozen_string_literal: true

class UpsertStatusSearchDocumentWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'search', retry: 3

  def perform(status_id)
    status = Status.unscoped
                   .includes(:account, :tags, :media_attachments, :preloadable_poll)
                   .find_by(id: status_id)

    if status.nil? || status.discarded?
      StatusSearchDocument.remove_for_status_id!(status_id)
      return
    end

    StatusSearchDocument.refresh_for_status!(status)
  rescue ActiveRecord::RecordNotFound
    StatusSearchDocument.remove_for_status_id!(status_id)
  end
end
