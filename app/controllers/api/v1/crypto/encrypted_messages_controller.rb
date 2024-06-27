# frozen_string_literal: true

class Api::V1::Crypto::EncryptedMessagesController < Api::BaseController
  LIMIT = 80

  before_action -> { doorkeeper_authorize! :crypto }
  before_action :require_user!
  before_action :set_current_device

  before_action :set_encrypted_messages,    only: :index
  after_action  :insert_pagination_headers, only: :index

  def index
    render json: @encrypted_messages, each_serializer: REST::EncryptedMessageSerializer
  end

  def clear
    @current_device.encrypted_messages.up_to(params[:up_to_id]).delete_all
    render_empty
  end

  private

  def set_current_device
    @current_device = Device.find_by!(access_token: doorkeeper_token)
  end

  def set_encrypted_messages
    @encrypted_messages = @current_device.encrypted_messages.to_a_paginated_by_id(limit_param(LIMIT), params_slice(:max_id, :since_id, :min_id))
  end

  def next_path
    api_v1_crypto_encrypted_messages_url pagination_params(max_id: pagination_max_id) if records_continue?
  end

  def prev_path
    api_v1_crypto_encrypted_messages_url pagination_params(min_id: pagination_since_id) unless @encrypted_messages.empty?
  end

  def pagination_collection
    @encrypted_messages
  end

  def records_continue?
    @encrypted_messages.size == limit_param(LIMIT)
  end
end
