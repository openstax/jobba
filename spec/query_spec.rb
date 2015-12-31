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

  it 'returns all statuses when not run on a chain' do
    unqueued = make_status(state: :unqueued, id: :unqueued)
    queued   = make_status(state: :queued, id: :queued_1)
    working  = make_status(state: :working, id: :working_1)

    expect(
      described_class.new.all.collect(&:id)
    ).to contain_exactly(unqueued.id, queued.id, working.id)
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

  # it 'does not blow up in this case' do
  #   expect{described_class.new.all}.not_to raise_error
  # end

  # A helper method for making Status objects with more control than is normally
  # available, to help with debugging specs
  def make_status(options)
    id = options[:id]
    state = options[:state]

    status =
      if id.nil?
        Jobba::Status.create!
      else
        # backdoor into creating a Status with a given ID to make test debugging easier

        raise "Cannot make a status with a specified ID if that ID already exists" \
          if Jobba::Status.find(id.to_s)

        Jobba::Status.find!(id.to_s)
      end

    # Whether or not all states are used is up to the code using this library;
    # for these specs, we assume that states are traversed in order.
    case state
    when :working
      status.queued!.working!
    when :succeeded
      status.queued!.working!.succeeded!
    when :failed
      status.queued!.working!.failed!
    else
      status.send("#{state}!") unless state.nil?
    end

    status
  end

  def where(options)
    described_class.new.where(options)
  end

end
