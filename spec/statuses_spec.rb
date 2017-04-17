require 'spec_helper'

describe Jobba::Statuses do

  it 'can get #to_a' do
    status_1 = Jobba::Status.create!
    status_2 = Jobba::Status.create!

    statuses = described_class.new([status_1.id, status_2.id])

    expect(statuses.to_a.collect(&:id)).to contain_exactly(status_1.id, status_2.id)
  end

  it 'is empty for nil ids' do
    statuses = described_class.new([nil])
    expect(statuses).to be_empty
  end

  it 'is empty for no init args' do
    statuses = described_class.new
    expect(statuses).to be_empty
  end

  it 'can return a count which respects only real data' do
    status_1 = make_status(id: :status_1)
    statuses = described_class.new(status_1.id, "made_up_id")
    expect(statuses.count).to eq 1
  end

  context 'standard array methods' do
    let!(:queued)    { make_status(state: :queued, id: :queued) }
    let!(:time)      { Jobba::Time.now }
    let!(:started)   { make_status(state: :started, id: :started) }

    let!(:statuses) { described_class.new(queued.id, started.id)}

    it 'has `any?`' do
      expect(statuses.any?{|ss| ss.progress == 1}).to be_falsy
      expect(statuses.any?{|ss| ss.queued?}).to be_truthy
      expect(statuses.any?(&:queued?)).to be_truthy
    end

    it 'has `none?`' do
      expect(statuses.none?{|ss| ss.progress == 1}).to be_truthy
      expect(statuses.none?{|ss| ss.queued?}).to be_falsy
    end

    it 'has `all?`' do
      expect(statuses.all?{|ss| ss.progress == 0}).to be_truthy
      expect(statuses.all?{|ss| ss.queued?}).to be_falsy
    end

    it 'has `map` and `collect`' do
      expect(statuses.map(&:id)).to contain_exactly("queued", "started")
      expect(statuses.collect(&:id)).to contain_exactly("queued", "started")
    end

    it 'has `reject!`' do
      expect(statuses.reject!(&:queued?).ids).to eq ["started"]
    end

    it 'has `select!`' do
      expect(statuses.select!(&:queued?).ids).to eq ["queued"]
    end
  end

  context 'deletion' do
    let!(:queued)    { make_status(state: :queued, id: :queued) }
    let!(:failed)    { make_status(state: :failed, id: :failed) }
    let!(:succeeded) { make_status(state: :succeeded, id: :succeeded) }

    let!(:statuses) { described_class.new(queued.id, failed.id, succeeded.id)}

    it 'does not delete_all when there are some incomplete' do
      expect{statuses.delete_all}.to raise_error(Jobba::NotCompletedError)
      expect(statuses.count).to eq 3
    end

    it 'does delete_all when there are no incompletes' do
      queued.delete!
      described_class.new(failed.id, succeeded.id).delete_all
      expect(Jobba.redis.keys("*").count).to eq 0
    end

    it 'does delete_all! when there are some incomplete' do
      expect{statuses.delete_all!}.to_not raise_error
      expect(statuses.count).to eq 0
      expect(statuses.to_a).to eq []
      expect(Jobba.redis.keys("*").count).to eq 0
    end

    it 'can delete_all! when there are restarted jobs' do
      failed.started! # restart
      statuses.delete_all!
      expect(Jobba.redis.keys("*").count).to eq 0
    end
  end

  it 'can bulk request kill' do
    queued =  make_status(state: :queued, id: :queued)
    started = make_status(state: :started, id: :started)

    statuses = described_class.new(queued.id, started.id)

    statuses.request_kill_all!
    expect(queued.reload!.kill_requested?).to be_truthy
    expect(started.reload!.kill_requested?).to be_truthy
  end

end
