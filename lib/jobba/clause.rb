class Jobba::Clause
  attr_reader :keys, :min, :max

  include Jobba::Common

  # if `keys` or `suffixes` is an array, all entries will be included in the resulting set
  def initialize(prefix: nil, suffixes: nil, keys: nil, min: nil, max: nil,
                 keys_contain_only_unique_ids: false)

    if keys.nil? && prefix.nil? && suffixes.nil?
      raise ArgumentError, "Either `keys` or both `prefix` and `suffix` must be specified.", caller
    end

    if (prefix.nil? && !suffixes.nil?) || (!prefix.nil? && suffixes.nil?)
      raise ArgumentError, "When `prefix` is given, so must `suffix` be, and vice versa.", caller
    end

    if keys
      @keys = [keys].flatten
    else
      prefix = "#{prefix}:" unless prefix[-1] == ":"
      @keys = [suffixes].flatten.collect{|suffix| "#{prefix}#{suffix}"}
    end

    @min = min
    @max = max

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

  def result_ids(offset: nil, limit: nil)
    # If we have one key and it is sorted, we can let redis return limited IDs,
    # so handle that case specially.

    id_data =
      if @keys.one?
        # offset and limit may or may not be used, so have to do again below
        get_members(key: @keys.first, offset: offset, limit: limit)
      else
        ids = @keys.flat_map do |key|
          # don't do limiting here -- doesn't make sense til we collect all the members
          get_members(key: key)[:ids]
        end

        ids.sort!
        ids.uniq! unless @keys_contain_only_unique_ids

        {ids: ids, is_limited: false}
      end

    if !offset.nil? && !limit.nil? && id_data[:is_limited] == false
      id_data[:ids].slice(offset, limit)
    else
      id_data[:ids]
    end
  end

  def get_members(key:, offset: nil, limit: nil)
    if sorted_key?(key)
      min = @min.nil? ? "-inf" : "#{@min}"
      max = @max.nil? ? "+inf" : "#{@max}"

      options = {}
      is_limited = false

      if !offset.nil? && !limit.nil?
        options[:limit] = [offset, limit]
        is_limited = true
      end

      ids = redis.zrangebyscore(key, min, max, options)

      {ids: ids, is_limited: is_limited}
    else
      ids = redis.smembers(key)
      ids.sort!
      {ids: ids, is_limited: false}
    end
  end

  def result_count(offset: nil, limit: nil)
    if @keys.one? || @keys_contain_only_unique_ids
      # can count each key on its own using fast redis ops and add them up
      nonlimited_count = @keys.map do |key|
        if sorted_key?(key)
          if @min.nil? && @max.nil?
            redis.zcard(key)
          else
            min = @min.nil? ? "-inf" : "#{@min}"
            max = @max.nil? ? "+inf" : "#{@max}"

            redis.zcount(key, min, max)
          end
        else
          redis.scard(key)
        end
      end.reduce(:+)

      Jobba::Utils.limited_count(nonlimited_count: nonlimited_count,
                                 offset: offset, limit: limit)
    else
      # Because we need to get a count of uniq members, have to do a full query
      result_ids(offset: offset, limit: limit).count
    end
  end

  def sorted_key?(key)
    key.match(/_at$/)
  end

end
