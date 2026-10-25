# frozen_string_literal: true

require 'rails_helper'

describe StatusSearchDocument do
  let(:account) { Fabricate(:account, indexable: true) }
  let(:status)  { Fabricate(:status, account: account, text: 'Hello ParadeDB full text search') }

  describe '.refresh_for_status!' do
    it 'creates a search document for a status' do
      expect {
        described_class.refresh_for_status!(status)
      }.to change(described_class, :count).by(1)

      doc = described_class.find_by(status_id: status.id)
      expect(doc.account_id).to eq(account.id)
      expect(doc.indexable).to be true
      expect(doc.visibility).to eq(Status.visibilities[:public])
    end

    it 'removes document if status is discarded' do
      described_class.refresh_for_status!(status)
      status.discard!

      described_class.refresh_for_status!(status)
      expect(described_class.find_by(status_id: status.id)).to be_nil
    end
  end
end
