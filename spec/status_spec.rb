require 'spec_helper'
require 'status_shared_examples'

describe Jobba::Status do

  include_examples 'status'

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
    before(:each) {
      @status = described_class.create!
      @status.set_job_name("do_stuff")
      @status.set_job_args(foo: "gid://app/MyModel/42")
      @status.set_provider_job_id(42)
      @status.queued!.started!
      @status.save('blah')
      @status.request_kill!
    }

    it 'gets rid of all knowledge of the status' do
      @status.delete!
      expect(Jobba.redis.keys("*")).to eq []
    end

    it 'gets rid of all knowledge of the status after a restart' do
      @status.started! # restart
      @status.delete!
      expect(Jobba.redis.keys("*")).to eq []
    end
  end

  describe '#delete' do
    it 'prevents an incomplete status from being deleted' do
      status = described_class.create!
      expect{status.delete}.to raise_error(Jobba::NotCompletedError)
    end
  end

  describe '#set_job_name' do
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

    it 'overwrites previous name and survives a reload' do
      @status.set_job_name("muppet")
      expect(@status.job_name).to eq "muppet"

      status = Jobba::Status.find(@status.id)
      expect(status.job_name).to eq "muppet"
    end
  end

  describe '#set_job_args' do
    before(:each) {
      @status = described_class.create!

      @status.set_job_args(arg1: "blah", 'arg2' => "42")
    }

    it 'returns job args' do
      expect(@status.job_args['arg1']).to eq "blah"
      expect(@status.job_args['arg2']).to eq "42"
    end

    it 'survives a reload' do
      status = Jobba::Status.find(@status.id)

      expect(status.job_args['arg1']).to eq "blah"
      expect(status.job_args['arg2']).to eq "42"
    end

    it 'overwrites on a second call and that overwrite survives reload' do
      @status.set_job_args(arg3: 'howdy')
      expect(@status.job_args.to_h).to eq({'arg3' => 'howdy'})

      status = Jobba::Status.find(@status.id)
      expect(status.job_args.to_h).to eq({'arg3' => 'howdy'})
    end
  end

  describe '#set_provider_job_id' do
    before(:each) {
      @status = described_class.create!
      @status.set_provider_job_id(42)
    }

    it 'returns job args' do
      expect(@status.provider_job_id).to eq 42
    end

    it 'survives a reload' do
      status = Jobba::Status.find(@status.id)
      expect(status.provider_job_id).to eq 42
    end

    it 'overwrites previous name and survives a reload' do
      @status.set_provider_job_id(84)
      expect(@status.provider_job_id).to eq 84

      status = Jobba::Status.find(@status.id)
      expect(status.provider_job_id).to eq 84
    end
  end

  describe 'restart' do

    [:succeeded, :started].each do |state|

      context "from `#{state}` status" do
        before(:each) {
          @status = make_status(state: state)
          @status.save('hi there')
          @status.set_job_name('job_name')
          @status.set_job_args(arg: "foo")
          @status.set_progress(0.7)
          @status.add_error("oh nooo!")

          @original_id = @status.id
          @original_recorded_at = @status.recorded_at
          @original_queued_at = @status.queued_at

          @status.started!
        }

        it 'is in started state' do
          expect(@status).to be_started
        end

        it 'did_start?' do
          expect(@status.did_start?).to be_truthy
        end

        it 'does not have data' do
          expect(@status.data).to be_nil
        end

        it 'does have a job name' do
          expect(@status.job_name).to eq "job_name"
        end

        it 'does not have job args' do
          expect(@status.job_args.to_h).to eq({'arg' => 'foo'})
        end

        it 'does not have errors' do
          expect(@status.errors).to be_empty
        end

        it 'has 0 progress' do
          expect(@status.progress).to eq 0
        end

        it 'maintains ID, recorded_at, queued_at' do
          expect(@status.id).to eq @original_id
          expect(@status.recorded_at).to eq @original_recorded_at
          expect(@status.queued_at).to eq @original_queued_at
        end

        it 'has an attempt of 1' do
          expect(@status.attempt).to eq 1
        end
      end
    end

    describe '#prior_attempts' do
      before(:each) {
        @status = make_status(state: :started)
        @status.save('1st attempt, attempt 0')
        @status.started!
        @status.save('2nd attempt, attempt 1')
        @status.started!
        @status.save('3rd attempt, attempt 2')
      }

      it 'counts attempts' do
        expect(@status.attempt).to eq 2
      end

      it 'can access prior attempts' do
        expect(@status.prior_attempts).to contain_exactly(
          kind_of(Jobba::Status),
          kind_of(Jobba::Status),
        )
      end

      it 'maintains data in prior attempts' do
        expect(@status.prior_attempts.collect(&:data)).to eq [
          '1st attempt, attempt 0',
          '2nd attempt, attempt 1'
        ]
      end

      it 'has an ID of the form id:N' do
        expect(@status.prior_attempts.collect(&:id)).to eq [
          "#{@status.id}:0",
          "#{@status.id}:1"
        ]
      end

      it 'deletes prior attempts when current status deleted' do
        prior_0, prior_1 = @status.prior_attempts
        prior_0_id = prior_0.id
        @status.delete!
        expect(Jobba::Status.find(prior_0_id)).to be_nil
      end
    end

  end

  describe 'errors' do
    let(:status) { make_status(state: :started) }

    describe 'adding' do
      it 'adds a simple hash error' do
        status.add_error({'message' => 'blah', 'foo' => 2})
        expect(status.errors).to eq [{'message' => 'blah', 'foo' => 2}]
      end

      it 'adds an arbitrary object as error' do
        class Error < Object
          def initialize
            @foo = 'bar'
          end
        end
        status.add_error(Error.new)
        expect(status.errors).to eq [{"foo"=>"bar"}]
      end

    end

    it 'lets you add an error and survives a manual reload' do
      status.add_error({'message' => 'blah', 'foo' => 2})
      found = Jobba::Status.find(status.id)
      expect(found.errors).to eq [{'message' => 'blah', 'foo' => 2}]
    end

    it 'lets you add multiple errors' do
      status.add_error("howdy")
      status.add_error(2)
      status.add_error([1,2,3])
      status.add_error(boo: 2)
      expect(status.errors).to eq ["howdy", 2, [1,2,3], {'boo' => 2}]
      found = Jobba::Status.find(status.id)
      expect(found.errors).to eq ["howdy", 2, [1,2,3], {'boo' => 2}]
      found.reload!
      expect(found.errors).to eq ["howdy", 2, [1,2,3], {'boo' => 2}]
    end
  end

end
