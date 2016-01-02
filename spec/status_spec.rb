require 'spec_helper'

describe Jobba::Status do

  it 'can create a Status' do
    status = described_class.create!

    expect(status.id).to be_a String
    expect(status.state).to eq Jobba::State::UNQUEUED
    expect(status.progress).to eq 0
    expect(status.errors).to be_empty
    expect(status.recorded_at).to be_a Time
    expect(status.unqueued?).to be_truthy

    # check that it got saved to redis
    expect(Jobba.redis.hgetall(described_class.job_key(status.id))).to include ({
      "id"=> "\"#{status.id}\"",
      "progress"=>"0",
      "errors"=>"[]",
      "state"=>"\"unqueued\"",
      "recorded_at" => be_a(String),
    })
  end

  describe '#find' do
    it 'returns a previously created status' do
      status_id = described_class.create!.id
      status = described_class.find(status_id)

      expect(status.id).to eq status_id
      expect(status.state).to eq Jobba::State::UNQUEUED
      expect(status.progress).to eq 0
      expect(status.errors).to be_empty
      expect(status.data).to be_nil
    end

    it 'returns nil when the status is not in redis' do
      expect(described_class.find('blah')).to be_nil
    end
  end

  describe '#find!' do
    it 'returns a previously created status' do
      status_id = described_class.create!.id
      status = described_class.find(status_id)

      expect(status.id).to eq status_id
      expect(status.state).to eq Jobba::State::UNQUEUED
      expect(status.progress).to eq 0
      expect(status.errors).to be_empty
      expect(status.data).to be_nil
      expect(status.recorded_at).to be_a(Time)
    end

    it 'creates an unknown status when the status is not in redis' do
      status = described_class.find!('blah')

      expect(status.id).to eq 'blah'
      expect(status.state).to eq Jobba::State::UNKNOWN
      expect(status.progress).to eq 0
      expect(status.errors).to be_empty
      expect(status.data).to be_empty
      expect(status.recorded_at).to be_a(Time)
    end
  end

  describe '#save' do
    it 'sets the redis value and the local instance variable' do
      status = described_class.create!
      status.save('howdy there')
      expect(status.data).to eq 'howdy there'
      expect(described_class.find(status.id).data).to eq 'howdy there'
    end

    it 'gives back same data regardless of if called after save or after reload' do
      status = described_class.create!
      status.save({a: 'blah'})
      expect(status.data).to eq ({'a' => 'blah'})
      status.reload!
      expect(status.data).to eq ({'a' => 'blah'})
    end
  end

  describe 'state checkers and setters' do
    it 'can progress through the states' do
      status = described_class.create!

      expect(status.state).to eq Jobba::State::UNQUEUED
      recorded_at = status.recorded_at
      expect(recorded_at).to be_a Time
      expect(status.unqueued?).to be_truthy
      expect(status.incomplete?).to be_truthy
      expect(status.completed?).to be_falsy

      status.queued!

      expect(status.state).to eq Jobba::State::QUEUED
      expect(status.queued_at).to be_a Time
      expect(status.unqueued?).to be_falsy
      expect(status.queued?).to be_truthy
      expect(status.recorded_at).to eq recorded_at
      expect(status.incomplete?).to be_truthy
      expect(status.completed?).to be_falsy

      # Do one check to make sure the attributes survive a reload
      status = Jobba::Status.find(status.id)

      expect(status.state).to eq Jobba::State::QUEUED
      expect(status.queued_at).to be_a Time
      expect(status.unqueued?).to be_falsy
      expect(status.queued?).to be_truthy
      expect(status.incomplete?).to be_truthy
      expect(status.completed?).to be_falsy

      status.started!

      expect(status.state).to eq Jobba::State::STARTED
      expect(status.started_at).to be_a Time
      expect(status.queued?).to be_falsy
      expect(status.started?).to be_truthy
      expect(status.incomplete?).to be_truthy
      expect(status.completed?).to be_falsy

      status.succeeded!

      expect(status.state).to eq Jobba::State::SUCCEEDED
      expect(status.succeeded_at).to be_a Time
      expect(status.started?).to be_falsy
      expect(status.succeeded?).to be_truthy
      expect(status.incomplete?).to be_falsy
      expect(status.completed?).to be_truthy

    end

    it 'does not change timestamps when state called a second time' do
      status = described_class.create!

      status.queued!
      queued_at = status.queued_at

      status.queued!
      expect(status.queued_at).to eq queued_at

      status = Jobba::Status.find(status.id)
      expect(status.queued_at).to eq queued_at
    end

    it 'can be failed!' do
      status = described_class.create!
      status.failed!

      expect(status.state).to eq Jobba::State::FAILED
      expect(status.failed_at).to be_a Time
      expect(status.failed?).to be_truthy
      expect(status.completed?).to be_truthy
    end
  end

  describe 'progress' do
    it 'can have its progress set with a number between 0 and 1' do
      status = described_class.create!
      expect(status.progress).to eq 0
      status.set_progress(0.1)
      expect(status.progress).to eq 0.1
      status = Jobba::Status.find(status.id)
      expect(status.progress).to eq 0.1
    end

    it 'can have its progress set with one number out of another' do
      status = described_class.create!
      status.set_progress(1,5)
      expect(status.progress).to eq 0.2
    end

    it 'needs `at` to be non-nil' do
      status = described_class.create!
      expect{status.set_progress(nil)}.to raise_error(ArgumentError)
    end

    it 'needs `at` to be >= 0' do
      status = described_class.create!
      expect{status.set_progress(-0.5)}.to raise_error(ArgumentError)
    end

    it 'needs `out_of` > `at`' do
      status = described_class.create!
      expect{status.set_progress(5,1)}.to raise_error(ArgumentError)
    end

    it 'needs `at` without `out_of` to be in [0,1]' do
      status = described_class.create!
      expect{status.set_progress(2)}.to raise_error(ArgumentError)
    end
  end

  describe '#save' do
    [
      "some string",
      [1, "2", {"a" => 4}],
      {"c" => "howdy"}
    ]
    .each do |data|
      it "saves client data '#{data}'" do
        status = described_class.create!
        status.save(data)
        expect(status.data).to eq data
        status = Jobba::Status.find(status.id)
        expect(status.data).to eq data
      end
    end

    it 'saves nil data' do
      status = described_class.create!
      status.save(nil)
      expect(status.data).to eq nil
      status = Jobba::Status.find(status.id)
      expect(status.data).to eq nil
    end
  end

  describe 'requested kills' do
    it 'allows kill to be requested' do
      status = described_class.create!
      expect(status.kill_requested?).to be_falsy
      expect(status.kill_requested_at).to be_nil

      prior_state = status.state

      status.request_kill!

      expect(status.kill_requested?).to be_truthy
      expect(status.kill_requested_at).to be_a(Time)
      expect(status.state).to eq prior_state

      status = Jobba::Status.find(status.id)

      expect(status.kill_requested?).to be_truthy
      expect(status.kill_requested_at).to be_a(Time)
      expect(status.state).to eq prior_state
    end

    it 'does not update timestamp for multiple requests' do
      status = described_class.create!
      status.request_kill!
      kill_requested_at = status.kill_requested_at
      status.request_kill!
      expect(status.kill_requested_at).to eq kill_requested_at
      status = Jobba::Status.find(status.id)
      expect(status.kill_requested_at).to eq kill_requested_at
    end
  end

  describe '#delete!' do
    it 'gets rid of all knowledge of the status' do
      status = described_class.create!
      status.set_job_name("do_stuff")
      status.add_job_arg(:foo, "gid://app/MyModel/42")
      status.queued!.started!
      status.request_kill!
      status.delete!
      expect(Jobba.redis.keys("*").count).to eq 0
    end
  end

  describe '#delete' do
    it 'prevents an incomplete status from being deleted' do
      status = described_class.create!
      expect{status.delete}.to raise_error(Jobba::NotCompletedError)
    end
  end

  describe '#add_job_name' do
    before(:each) {
      @status = described_class.create!
      @status.set_job_name("fluffy")
    }

    it 'returns job args' do
      expect(@status.job_name).to eq "fluffy"
    end

    it 'survives a reload' do
      status = Jobba::Status.find(@status.id)
      expect(status.job_name).to eq "fluffy"
    end
  end

  describe '#add_job_arg' do
    before(:each) {
      @status = described_class.create!

      @status.add_job_arg(:arg1, "blah")
      @status.add_job_arg('arg2', "42")
    }

    it 'returns job args' do
      expect(@status.job_args['arg1']).to eq "blah"
      expect(@status.job_args[:arg2]).to eq "42"
    end

    it 'survives a reload' do
      status = Jobba::Status.find(@status.id)

      expect(status.job_args['arg1']).to eq "blah"
      expect(status.job_args[:arg2]).to eq "42"
    end
  end

end
