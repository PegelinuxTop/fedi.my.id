# frozen_string_literal: true

require 'rails_helper'

describe ParadedbQueryTransformer do
  subject { described_class.new }

  let(:account) { Fabricate(:account) }

  describe '#parse' do
    it 'parses bare words into must clauses' do
      ast = SearchQueryParser.new.parse('hello world')
      query = subject.parse(ast, current_account: account)
      clauses = query.clauses

      expect(clauses.map(&:term)).to include('hello', 'world')
    end

    it 'parses prefix filters' do
      ast = SearchQueryParser.new.parse('from:me has:media in:library')
      query = subject.parse(ast, current_account: account)
      clauses = query.clauses

      prefix_clauses = clauses.select { |c| c.operator == :filter }
      expect(prefix_clauses.map(&:prefix)).to include('from', 'has')
    end
  end
end
