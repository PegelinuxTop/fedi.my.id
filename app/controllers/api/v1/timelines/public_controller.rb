# frozen_string_literal: true

class Api::V1::Timelines::PublicController < Api::V1::Timelines::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:statuses' }

  PERMITTED_PARAMS = %i(local remote bubble limit only_media allow_local_only).freeze

  def show
    cache_if_unauthenticated!
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def load_statuses
    preloaded_public_statuses_page
  end

  def preloaded_public_statuses_page
    preload_collection(public_statuses, Status)
  end

  def public_statuses
    public_feed.get(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def public_feed
    PublicFeed.new(
      current_account,
      local: truthy_param?(:local),
      bubble: truthy_param?(:bubble),
      remote: truthy_param?(:remote),
      only_media: truthy_param?(:only_media),
      allow_local_only: truthy_param?(:allow_local_only),
      with_replies: truthy_param?(:local) ? Setting.show_replies_in_local_timelines : Setting.show_replies_in_federated_timelines,
      with_reblogs: truthy_param?(:local) ? Setting.show_reblogs_in_local_timelines : Setting.show_reblogs_in_federated_timelines
    )
  end

  def next_path
    api_v1_timelines_public_url next_path_params
  end

  def prev_path
    api_v1_timelines_public_url prev_path_params
  end
end
