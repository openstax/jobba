require 'spec_helper'

describe Jobba do

  it 'has working `where`, `all`, and `count` methods' do
    # smoke tests since just delegates to Query

    unqueued = Jobba::Status.create!
    queued_1 = Jobba::Status.create!.queued!
    queued_2 = Jobba::Status.create!.queued!
    working  = Jobba::Status.create!.working!

    expect(Jobba.where(state: :queued).ids).to contain_exactly(queued_1.id, queued_2.id)
    expect(Jobba.all.collect(&:id)).to contain_exactly(unqueued.id, queued_1.id, queued_2.id, working.id)
    expect(Jobba.count).to eq 4
  end

end
