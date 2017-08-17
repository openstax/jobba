require 'spec_helper'

describe Jobba::Utils do

  describe '#time_to_usec_int' do
    let!(:time)     { Jobba::Time.new(2015,12,28,10,32,33,"-08:00") }
    let!(:usec_int) { 1451327553000000 }

    it 'gives the expected output for Time input' do
      expect(described_class.time_to_usec_int(time)).to eq usec_int
    end

    it 'gives the expected output for float input' do
      expect(described_class.time_to_usec_int(time.to_f)).to eq usec_int
    end

    it 'gives the expected output for int input' do
      expect(described_class.time_to_usec_int(usec_int)).to eq usec_int
    end

    it 'gives the expected output for string input' do
      expect(described_class.time_to_usec_int(usec_int.to_s)).to eq usec_int
    end
  end

  describe '#time_from_usec_int' do
    let!(:time)     { Jobba::Time.now }

    it 'converts correctly' do
      usec_int = described_class.time_to_usec_int(time)
      expect(described_class.time_from_usec_int(usec_int)).to eq time
    end
  end

  describe '#limited_count' do

    it 'does not limit when offset and limit are nil' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: nil, limit: nil)).to eq 10
    end

    it 'does not limit when offset and limit do not limit' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 0, limit: 10)).to eq 10
    end

    it 'limits when limit causes us to run off the end' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 9, limit: 2)).to eq 1
    end

    it 'works when limit and offset take us to the end exactly' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 9, limit: 1)).to eq 1
    end

    it 'limits when offset starts us off the end' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 11, limit: 42)).to eq 0
      expect(described_class.limited_count(nonlimited_count: 10, offset: 10, limit: 0)).to eq 0
    end

    it 'limits when limit and offset do not run off the end' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 2, limit: 5)).to eq 5
    end

    it 'limits when offset nil but limit set' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: nil, limit: 2)).to eq 2
      expect(described_class.limited_count(nonlimited_count: 10, offset: nil, limit: 11)).to eq 10
    end

    it 'limits when offset set but limit nil' do
      expect(described_class.limited_count(nonlimited_count: 10, offset: 7, limit: nil)).to eq 3
      expect(described_class.limited_count(nonlimited_count: 10, offset: 10, limit: nil)).to eq 0
    end
  end


end
