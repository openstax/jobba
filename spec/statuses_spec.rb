require 'spec_helper'

describe Jobba::Statuses do

  it 'can get #all' do
    status_1 = Jobba::Status.create!
    status_2 = Jobba::Status.create!

    statuses = described_class.new([status_1.id, status_2.id])

    expect(statuses.all.collect(&:id)).to contain_exactly(status_1.id, status_2.id)
  end

  it 'is empty for nil ids' do
    statuses = described_class.new([nil])
    expect(statuses).to be_empty
    expect(statuses.first).to be_nil
  end

  it 'is empty for no init args' do
    statuses = described_class.new
    expect(statuses).to be_empty
    expect(statuses.first).to be_nil
  end

  context 'standard array methods' do
    let!(:queued)    { make_status(state: :queued, id: :queued) }
    let!(:time)      { Jobba::Time.now }
    let!(:working)   { make_status(state: :working, id: :working) }

    let!(:statuses) { described_class.new(queued.id, working.id)}

    it 'has `first`' do
      expect(statuses.first).to_not be_nil
    end

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
      expect(statuses.map(&:id)).to contain_exactly("queued", "working")
      expect(statuses.collect(&:id)).to contain_exactly("queued", "working")
    end

    it 'has `each`' do
      expect(statuses.each{|ss| %w(queued working).include?(ss.id)})
    end

    it 'has `select`' do
      expect(statuses.select(&:queued?).first.id).to eq "queued"
    end
  end

end
