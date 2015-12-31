class Jobba::Clause
  attr_reader :key, :min, :max

  include Jobba::Common

  # if `key` is an array of keys, all values from all keys will be included
  def initialize(key:, min: nil, max: nil)
    @key = key
    @min = min
    @max = max
  end

  def to_new_set
    new_key = "temp:#{SecureRandom.hex(10)}"

    # Make a copy of the data into new_key then filter values if indicated
    # (always making a copy gets normal sets into a sorted set key OR if
    # already sorted gives us a safe place to filter out values without
    # perturbing the original sorted set).

    redis.zunionstore(new_key, [key].flatten)
    redis.zremrangebyscore(new_key, '-inf', "(#{min}") unless min.nil?
    redis.zremrangebyscore(new_key, "(#{max}", '+inf') unless max.nil?

    new_key
  end
end
