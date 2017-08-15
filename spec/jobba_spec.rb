require 'spec_helper'
require 'status_shared_examples'

describe Jobba do

  it_behaves_like 'status'

  it 'computes `all.count` efficiently' do
    2.times { make_status(state: :unqueued) }
    1.times { make_status(state: :succeeded) }
    3.times { make_status(state: :started) }

    expect(Jobba.redis).to receive(:scard).exactly(Jobba::State::ALL.count).times.and_call_original
    expect(Jobba.all.count).to eq 6
  end

end
