class Jobba::Clause
  attr_reader :keys, :min, :max

  include Jobba::Common

  # if `keys` or `suffixes` is an array, all entries will be included in the resulting set
  def initialize(prefix: nil, suffixes: nil, keys: nil, min: nil, max: nil)
    if keys.nil? && prefix.nil? && suffixes.nil?
      raise ArgumentError, "Either `keys` or both `prefix` and `suffix` must be specified."
    end

    if (prefix.nil? && !suffixes.nil?) || (!prefix.nil? && suffixes.nil?)
      raise ArgumentError, "When `prefix` is given, so must `suffix` be, and vice versa."
    end

    if keys
      @keys = [keys].flatten
    else
      prefix = "#{prefix}:" unless prefix[-1] == ":"
      @keys = [suffixes].flatten.collect{|suffix| prefix + suffix}
    end

    @min = min
    @max = max
  end

  def to_new_set
    new_key = Jobba::Utils.temp_key

    # Make a copy of the data into new_key then filter values if indicated
    # (always making a copy gets normal sets into a sorted set key OR if
    # already sorted gives us a safe place to filter out values without
    # perturbing the original sorted set).

    if !keys.empty?
      redis.zunionstore(new_key, keys)
      redis.zremrangebyscore(new_key, '-inf', "(#{min}") unless min.nil?
      redis.zremrangebyscore(new_key, "(#{max}", '+inf') unless max.nil?
    end

    new_key
  end

end
