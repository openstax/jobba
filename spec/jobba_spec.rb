require 'spec_helper'

describe Jobba do

  it 'has working `where` and `all` methods' do
    # smoke tests since just delegates to Query

    unqueued = Jobba::Status.create!
    queued_1 = Jobba::Status.create!.queued!
    queued_2 = Jobba::Status.create!.queued!
    started  = Jobba::Status.create!.started!

    expect(Jobba.where(state: :queued).ids).to contain_exactly(queued_1.id, queued_2.id)
    expect(Jobba.all.collect(&:id)).to contain_exactly(unqueued.id, queued_1.id, queued_2.id, started.id)
  end

end
