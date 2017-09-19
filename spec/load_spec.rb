require 'spec_helper'

# Run this on its own with `USE_REAL_REDIS=true rspec ./spec/load_spec.rb`
xdescribe 'Load performance' do

  before(:each) do
    # This takes a long time.
    t = Time.now
    100.times{ |i|
      puts "#{i}: #{Time.now - t}"
      t = Time.now
      10000.times { Jobba::Status.create! }
    }
  end

  it 'runs Jobba.all.count quickly' do
    t = Time.now
    Jobba.all.count
    expect(Time.now - t).to be < 1.0
  end

end
