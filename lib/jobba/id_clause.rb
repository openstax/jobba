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

  def result_ids
    @ids.map(&:to_s)
  end

  def result_count
    @ids.count
  end
end
