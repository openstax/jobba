require 'spec_helper'

shared_examples 'status' do

  it 'has working `where` and `all` methods' do
    # smoke tests since just delegates to Query

    unqueued = Jobba::Status.create!
    queued_1 = Jobba::Status.create!.queued!
    queued_2 = Jobba::Status.create!.queued!
    started  = Jobba::Status.create!.started!

    expect(described_class.where(state: :queued).ids).to contain_exactly(queued_1.id, queued_2.id)
    expect(described_class.all.collect(&:id)).to(
      contain_exactly(unqueued.id, queued_1.id, queued_2.id, started.id)
    )
  end

  it 'can create a Status' do
    status = described_class.create!

    expect(status.id).to be_a String
    expect(status.state).to eq Jobba::State::UNQUEUED
    expect(status.progress).to eq 0
    expect(status.errors).to be_empty
    expect(status.recorded_at).to be_a Time
    expect(status.unqueued?).to be_truthy
    expect(status.attempt).to eq 0
    expect(status.job_args.to_h).to eq({})

    # check that it got saved to redis
    expect(Jobba.redis.hgetall(Jobba::Status.job_key(status.id))).to include ({
      "id"=> "\"#{status.id}\"",
      "progress"=>"0",
      "errors"=>"[]",
      "state"=>"\"unqueued\"",
      "attempt"=>"0",
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

end
