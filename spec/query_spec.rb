require 'spec_helper'

describe Jobba::Query do

  it 'can get statuses of one state' do
    Jobba::Status.create!
    queued_1 = Jobba::Status.create!.queued!
    queued_2 = Jobba::Status.create!.queued!
    Jobba::Status.create!.working!

    expect(where(state: :queued).ids).to contain_exactly(queued_1.id, queued_2.id)
  end

  it 'can return an empty result' do
    expect(where(state: :queued).ids).to be_empty
  end

  it 'can have `all` run on a chain' do
    queued = Jobba::Status.create!.queued!
    Jobba::Status.create!.working!

    expect(where(state: :queued).all.collect(&:id)).to contain_exactly(queued.id)
  end

  it 'returns all statuses when not run on a chain' do
    unqueued = make_status(state: :unqueued, id: :unqueued)
    queued   = make_status(state: :queued, id: :queued_1)
    working  = make_status(state: :working, id: :working_1)

    expect(
      described_class.new.all.collect(&:id)
    ).to contain_exactly(unqueued.id, queued.id, working.id)
  end

  it 'freaks out if a timestamp name is invalid' do
    expect{where(working_at: [nil, nil])}.to raise_error(ArgumentError)
  end

  it 'can get statuses from multiple states' do
    unqueued = make_status(state: :unqueued, id: :unqueued)
    queued   = make_status(state: :queued, id: :queued_1)
    working  = make_status(state: :working, id: :working_1)

    expect(
      where(state: [:unqueued, :working]).ids
    ).to contain_exactly(unqueued.id, working.id)
  end

  it 'counts `where` results without bringing statuses back from redis' do
    queued   = make_status(state: :queued, id: :queued_1)
    working  = make_status(state: :working, id: :working_1)

    expect(Jobba.redis).not_to receive(:mget)
    expect(where(state: :working).count).to eq 1
  end

  # describe 'timestamp queries' do
  #   it 'works with the bracket notation'
  # end

  context 'query scenario 1' do
    let!(:unqueued)    { make_status(state: :unqueued, id: :unqueued) }
    let!(:queued_1)    { make_status(state: :queued, id: :queued_1) }
    let!(:working_1)   { make_status(state: :working, id: :working_1) }
    let!(:time_1)      { Jobba::Time.now }
    let!(:queued_2)    { make_status(state: :queued, id: :queued_2) }
    let!(:working_2)   { make_status(state: :working, id: :working_2) }
    let!(:time_2)      { Jobba::Time.now }
    let!(:working_3)   { make_status(state: :working, id: :working_3) }

    it 'can get statuses for a state and a timestamp' do
      expect(where(state: :queued).where(recorded_at: [nil, time_1]).ids).to eq [queued_1.id]
    end

    it 'can get statuses with multiple conditions in one `where`' do
      expect(where(state: :queued, recorded_at: [nil, time_1]).ids).to eq [queued_1.id]
    end

    it 'can get statuses for multiple timestamps' do
      expect(
        where(queued_at: [time_1, nil]).where(started_at: [nil, time_2]).ids
      ).to eq [working_2.id]

      expect(
        where(queued_at: [time_1, nil]).where(started_at: [time_2, nil]).ids
      ).to eq [working_3.id]
    end

    it 'does not leave temporary keys around' do
      [
        -> { where(state: :queued) },
        -> { where(state: :queued).where(recorded_at: [nil, time_1]) },
        -> { where(state: :queued).where(recorded_at: [nil, time_1]).where(state: :working) }
      ]
      .each do |query|
        expect(&query).not_to change{Jobba.redis.keys.count}
      end
    end
  end

  context 'convenience queries' do
    let!(:queued)    { make_status(state: :queued, id: :queued) }
    let!(:working)   { make_status(state: :working, id: :working) }
    let!(:killed)   { make_status(state: :killed, id: :killed) }
    let!(:succeeded)   { make_status(state: :succeeded, id: :succeeded) }
    let!(:failed)   { make_status(state: :failed, id: :failed) }

    it 'returns completed statuses' do
      expect(
        where(state: :completed).ids
      ).to contain_exactly(succeeded.id, failed.id)
    end

    it 'returns incomplete statuses' do
      expect(
        where(state: :incomplete).ids
      ).to contain_exactly(queued.id, working.id, killed.id)
    end
  end

  context 'job_name queries' do
    let!(:status_1) { make_status(id: :status_1) }
    let!(:status_2) { make_status(id: :status_2).tap{|ss| ss.set_job_name("fluffy")} }
    let!(:status_3) { make_status(id: :status_3).tap{|ss| ss.set_job_name("fluffy")} }
    let!(:status_4) { make_status(id: :status_4).tap{|ss| ss.set_job_name("yeehaw")} }

    it 'finds statuses for one job name' do
      expect(
        where(job_name: "fluffy").ids
      ).to contain_exactly(status_2.id, status_3.id)
    end

    it 'finds statuses for two job names' do
      expect(
        where(job_name: ["fluffy", "yeehaw"]).ids
      ).to contain_exactly(status_2.id, status_3.id, status_4.id)
    end

    it 'returns no statuses for empty job_name search' do
      expect(
        where(job_name: []).ids
      ).to be_empty
    end
  end

  context 'job_arg queries' do
    let!(:status_1) { make_status(id: :status_1) }
    let!(:status_2) { make_status(id: :status_2).tap{|ss| ss.add_job_arg(:a, "A")} }
    let!(:status_3) { make_status(id: :status_3).tap{|ss| ss.add_job_arg('b', "B")} }
    let!(:status_4) { make_status(id: :status_4).tap{|ss| ss.add_job_arg('a', "A")} }

    it 'finds statuses for one job arg that has one status' do
      expect(
        where(job_arg: "B").ids
      ).to contain_exactly(status_3.id)
    end

    it 'finds statuses for one job arg that has two statuses' do
      expect(
        where(job_arg: "A").ids
      ).to contain_exactly(status_2.id, status_4.id)
    end

    it 'finds statuses for multiple job args' do
      expect(
        where(job_arg: ["A", "B"]).ids
      ).to contain_exactly(status_2.id, status_3.id, status_4.id)
    end

    it 'finds statuses for multiple job args with repeats' do
      expect(
        where(job_arg: ["A", "A"]).ids
      ).to contain_exactly(status_2.id, status_4.id)
    end
  end



  def where(options)
    described_class.new.where(options)
  end

end
