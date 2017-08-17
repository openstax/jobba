class Jobba::IdClause

  include Jobba::Common

  def initialize(ids)
    @ids = [ids].flatten.compact
  end

  def to_new_set
    new_key = Jobba::Utils.temp_key
    redis.zadd(new_key, @ids.collect{|id| [0, id]}) if @ids.any?
    new_key
  end

  def result_ids(offset: nil, limit: nil)
    @ids.map(&:to_s).slice(offset || 0, limit || @ids.count)
  end

  def result_count(offset: nil, limit: nil)
    Jobba::Utils.limited_count(nonlimited_count: @ids.count, offset: offset, limit: limit)
  end
end
