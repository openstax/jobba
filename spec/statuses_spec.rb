require 'spec_helper'

describe Jobba::Statuses do

  it 'can get #all' do
    status_1 = Jobba::Status.create!
    status_2 = Jobba::Status.create!

    statuses = described_class.new([status_1.id, status_2.id])

    expect(statuses.all.collect(&:id)).to contain_exactly(status_1.id, status_2.id)
  end

end
