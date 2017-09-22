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

  it 'can cleanup old statuses' do
    current_time = Jobba::Time.now

    tested_months = 0.upto(59).to_a
    tested_months.each do |nn|
      job = Jobba::Status.create!
      job.send :set, recorded_at: current_time - nn*60*60*24*30 # 1 month
    end

    expect { Jobba.cleanup }.to change { Jobba.all.count }.from(60).to(12)
    expect(Jobba.all.map(&:recorded_at).min).to be > current_time - 60*60*24*30*12 # 1 year
  end

end
