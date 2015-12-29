require 'spec_helper'

describe Jobba::State do

  it 'can get from name' do
    Jobba::State::ALL.each do |state|
      expect(described_class.from_name(state.name)).to eq state
    end
  end

end
