# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Statuses::ReactionsController do
  let(:user) { Fabricate(:user) }
  # named `application`, not `app`: in a request spec `app` is the Rack app under test
  let(:application) { Fabricate(:application, name: 'Test app', website: 'http://testapp.com') }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:favourites', application: application) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  # The request-spec helpers this spec used to rely on do not define
  # `body_as_json` any more, and it predates the routes it should use.
  def body_as_json
    JSON.parse(response.body, symbolize_names: true)
  end

  describe 'POST /api/v1/statuses/:status_id/react/:id' do
    context 'with public status' do
      let(:status) { Fabricate(:status, account: user.account) }

      before do
        post "/api/v1/statuses/#{status.id}/react/#{CGI.escape('👍')}", headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'updates the reacted attribute' do
        expect(user.account.reacted?(status, '👍')).to be true
      end

      it 'returns json with updated attributes' do
        hash_body = body_as_json

        expect(hash_body[:id]).to eq status.id.to_s
        expect(hash_body[:reactions]).to_not be_empty
        expect(hash_body[:reactions][0][:count]).to be 1
        expect(hash_body[:reactions][0][:me]).to be true
        expect(hash_body[:reactions][0][:name]).to eq '👍'
      end
    end

    context 'with private status of not-followed account' do
      let(:status) { Fabricate(:status, visibility: :private) }

      before do
        post "/api/v1/statuses/#{status.id}/react/#{CGI.escape('👍')}", headers: headers
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'POST /api/v1/statuses/:status_id/unreact/:id' do
    context 'with public status' do
      let(:status) { Fabricate(:status, account: user.account) }

      before do
        ReactService.new.call(user.account, status, '👍')
        post "/api/v1/statuses/#{status.id}/unreact/#{CGI.escape('👍')}", headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'updates the reacted attribute', :inline_jobs do
        expect(user.account.reacted?(status, '👍')).to be false
      end

      it 'returns json with updated attributes', :inline_jobs do
        hash_body = body_as_json

        expect(hash_body[:id]).to eq status.id.to_s
        expect(hash_body[:reactions]).to be_empty
      end
    end

    context 'with public status when blocked by its author' do
      let(:status) { Fabricate(:status) }

      before do
        ReactService.new.call(user.account, status, '👍')
        status.account.block!(user.account)
        post "/api/v1/statuses/#{status.id}/unreact/#{CGI.escape('👍')}", headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
      end

      it 'updates the reacted attribute', :inline_jobs do
        expect(user.account.reacted?(status, '👍')).to be false
      end

      it 'returns json with updated attributes', :inline_jobs do
        hash_body = body_as_json

        expect(hash_body[:id]).to eq status.id.to_s
        expect(hash_body[:reactions]).to be_empty
      end
    end

    context 'with private status that was not reacted to' do
      let(:status) { Fabricate(:status, visibility: :private) }

      before do
        post "/api/v1/statuses/#{status.id}/unreact/#{CGI.escape('👍')}", headers: headers
      end

      it 'returns http not found' do
        expect(response).to have_http_status(404)
      end
    end
  end
end
