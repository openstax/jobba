require 'spec_helper'

describe Jobba::IdClause do

  context '#result_ids' do
    it 'gets statuses when ids are strings' do
      expect(described_class.new(['hi', 'there']).result_ids).to eq (['hi', 'there'])
    end

    it 'gets statuses when ids are symbols' do
      expect(described_class.new([:hi, :there]).result_ids).to eq (['hi', 'there'])
    end
  end

  context '#result_count' do
    it 'works with 2 ids' do
      expect(described_class.new(['hi', 'there']).result_count).to eq 2
    end

    it 'works with no ids' do
      expect(described_class.new(nil).result_count).to eq 0
    end
  end

end
