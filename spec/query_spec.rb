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

  # describe 'timestamp queries' do
  #   it 'works with the bracket notation'
  # end

  context 'query scenario 1' do
    let!(:unqueued)    { Jobba::Status.create! }
    let!(:queued_1)    { Jobba::Status.create!.queued! }
    let!(:working_1)   { Jobba::Status.create!.queued!.working!}
    let!(:time_1)      { Time.now }
    let!(:queued_2)    { Jobba::Status.create!.queued! }
    let!(:working_2)   { Jobba::Status.create!.queued!.working! }

    it 'can get statuses for a state and a timestamp' do
      expect(where(state: :queued).where(recorded_at: [nil, time_1]).ids).to eq [queued_1.id]
    end

    it 'can get statuses for multiple timestamps' do
      expect(
        where(queued_at: [time_1, nil]).where(started_at: [time_1, nil]).ids
      ).to eq [working_2.id]
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



  def where(options)
    described_class.new.where(options)
  end

end
