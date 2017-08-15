class Jobba::Clause
  attr_reader :keys, :min, :max, :offset, :limit

  include Jobba::Common

  # if `keys` or `suffixes` is an array, all entries will be included in the resulting set
  def initialize(prefix: nil, suffixes: nil, keys: nil, min: nil, max: nil,
                 offset: nil, limit: nil, keys_contain_only_unique_ids: false)

    if keys.nil? && prefix.nil? && suffixes.nil?
      raise ArgumentError, "Either `keys` or both `prefix` and `suffix` must be specified.", caller
    end

    if (prefix.nil? && !suffixes.nil?) || (!prefix.nil? && suffixes.nil?)
      raise ArgumentError, "When `prefix` is given, so must `suffix` be, and vice versa.", caller
    end

    if (offset.nil? && !limit.nil?) || (!offset.nil? && limit.nil?)
      raise ArgumentError, "When `offset` is given, so must `limit` be, and vice versa.", caller
    end

    if keys
      @keys = [keys].flatten
    else
      prefix = "#{prefix}:" unless prefix[-1] == ":"
      @keys = [suffixes].flatten.collect{|suffix| "#{prefix}#{suffix}"}
    end

    @min = min
    @max = max

    @offset = offset
    @limit = limit

    @keys_contain_only_unique_ids = keys_contain_only_unique_ids
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

  def result_ids
    # If we have one key and it is sorted, we can let redis return limited IDs,
    # so handle that case specially.

    if @keys.one?
      ids = get_members(key: @keys.first, use_limit_if_sorted_set: true)
    else
      ids = @keys.flat_map do |key|
        get_members(key: key, use_limit_if_sorted_set: false)
      end

      ids.sort!
      ids.uniq! unless @keys_contain_only_unique_ids
    end

    # This may repeat limiting done by redis, but no biggie
    if !@offset.nil? && !@limit.nil?
      ids.slice(@offset, @limit)
    else
      ids
    end
  end

  def get_members(key:, use_limit_if_sorted_set: false)
    if sorted_key?(key)
      min = @min.nil? ? "-inf" : "(#{@min}"
      max = @max.nil? ? "+inf" : "(#{@max}"

      options = {}
      options[:limit] = [@offset, @limit] if use_limit_if_sorted_set && !@offset.nil? && !@limit.nil?

      ids = redis.zrangebyscore(key, min, max, options)
    else
      ids = redis.smembers(key)
      ids.sort!
    end

    ids
  end

  def result_count
    if @keys.one? || @keys_contain_only_unique_ids
      # can count each key on its own using fast redis ops and add them up
      unlimited_count = @keys.map do |key|
        if sorted_key?(key)
          if @min.nil? && @max.nil?
            redis.zcard(key)
          else
            min = @min.nil? ? "-inf" : "(#{@min}"
            max = @max.nil? ? "+inf" : "(#{@max}"

            redis.zcount(key, min, max)
          end
        else
          redis.scard(key)
        end
      end.reduce(:+)

      [unlimited_count, @limit].compact.min
    else
      # Because we need to get a count of uniq members, have to do a full query
      result_ids.count
    end
  end

  def sorted_key?(key)
    key.match(/_at$/)
  end

end
