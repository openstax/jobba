require 'spec_helper'

describe Jobba::ClauseFactory do

  context 'timestamp clauses' do
    it 'works with bracket notation' do
      clause = described_class.new_clause('queued_at', [0,1])
      expect(clause.keys).to eq ['queued_at']
      expect(clause.min).to eq 0
      expect(clause.max).to eq 1
    end

    it 'works with :before notation' do
      clause = described_class.new_clause('queued_at', before: 2)
      expect(clause.min).to eq nil
      expect(clause.max).to eq 2
    end

    it 'works with :after notation' do
      clause = described_class.new_clause('queued_at', after: 2)
      expect(clause.min).to eq 2
      expect(clause.max).to eq nil
    end

    it 'works with :before and :after notation' do
      clause = described_class.new_clause('queued_at', after: 2, before: 5)
      expect(clause.min).to eq 2
      expect(clause.max).to eq 5
    end

    it 'does not like bad timestamp names' do
      expect{described_class.new_clause('blah_at', nil)}.to raise_error(ArgumentError)
    end
  end

  context 'state clauses' do
    it 'works with one state' do
      clause = described_class.new_clause('state', 'queued')
      expect(clause.keys).to eq ['queued']
    end

    it 'works with two states' do
      clause = described_class.new_clause('state', ['queued', 'started'])
      expect(clause.keys).to eq ['queued', 'started']
    end

    it 'does not like bad state names' do
      expect{described_class.new_clause(:state, 'blah')}.to raise_error(ArgumentError)
    end
  end

end

