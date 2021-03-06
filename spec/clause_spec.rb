require 'spec_helper'

describe Jobba::Clause do

  context '#get_members' do
    context 'sorted set' do
      before(:each) { Jobba.redis.zadd("blah_at", [[1, "a"], [2, "b"], [3, "c"], [4, "d"]]) }
      after(:each)  { Jobba.redis.del("blah_at") }

      it 'filters by min only' do
        expect(
          described_class.new(keys: "blah_at", min: 2).get_members(key: "blah_at")
        ).to eq ({ids: %w(b c d), is_limited: false})
      end

      it 'filters by max only' do
        expect(
          described_class.new(keys: "blah_at", max: 2).get_members(key: "blah_at")
        ).to eq ({ids: %w(a b), is_limited: false})
      end

      it 'filters by min and max' do
        expect(
          described_class.new(keys: "blah_at", min: 2, max: 3).get_members(key: "blah_at")
        ).to eq ({ids: %w(b c), is_limited: false})
      end

      it 'limits' do
        expect(
          described_class.new(keys: "blah_at").get_members(key: "blah_at", offset: 1, limit: 2)
        ).to eq ({ids: %w(b c), is_limited: true})
      end

      it 'filters by min/max and limits' do
        expect(
          described_class.new(keys: "blah_at", min: 2, max: 4).get_members(key: "blah_at", offset: 0, limit: 1)
        ).to eq ({ids: %w(b), is_limited: true})
      end
    end

    context 'unsorted set' do
      before(:each) { Jobba.redis.sadd("blah", ["a", "b", "c"]) }

      it 'returns all members' do
        expect(described_class.new(keys: "blah").get_members(key: "blah")[:ids]).to contain_exactly("a", "b", "c")
      end
    end
  end

  context '#result_ids and #result_count' do
    before(:each) do
      Jobba.redis.zadd("blah_at", [[1, "a"], [2, "b"], [3, "c"], [4, "d"]])
      Jobba.redis.sadd("blah", ["c", "b", "a", "e"])
    end
    after(:each)  do
      Jobba.redis.del("blah_at")
      Jobba.redis.del("blah")
    end

    it 'works on one sorted set' do
      clause = described_class.new(keys: "blah_at")
      expect(clause.result_ids).to eq %w(a b c d)
      expect(clause.result_count).to eq 4
    end

    it 'works on one unsorted set' do
      clause = described_class.new(keys: "blah")
      expect(clause.result_ids).to eq %w(a b c e)
      expect(clause.result_count).to eq 4
    end

    it 'works on sorted and unsorted sets together' do
      clause = described_class.new(keys: ["blah", "blah_at"])
      expect(clause.result_ids).to eq %w(a b c d e)
      expect(clause.result_count).to eq 5
    end

    it 'can limit on combo of sorted and unsorted' do
      clause = described_class.new(keys: ["blah", "blah_at"])
      expect(clause.result_ids(offset: 1, limit: 2)).to eq %w(b c)
      expect(clause.result_count(offset: 1, limit: 2)).to eq 2
    end

    it 'ignores uniqueness concerns if we set keys_contain_only_unique_ids' do
      clause = described_class.new(keys: ["blah", "blah_at"], keys_contain_only_unique_ids: true) # not really true
      expect(clause.result_ids).to eq %w(a a b b c c d e)
      expect(clause.result_count).to eq 8
    end
  end

end
