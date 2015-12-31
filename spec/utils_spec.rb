require 'spec_helper'

describe Jobba::Utils do

  describe '#time_to_usec_int' do
    let!(:time)     { Time.new(2015,12,28) }
    let!(:usec_int) { 1451289600000000 }

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
    let!(:time)     { Time.now }

    it 'converts correctly' do
      usec_int = described_class.time_to_usec_int(time)
      expect(described_class.time_from_usec_int(usec_int)).to eq time
    end
  end


end
