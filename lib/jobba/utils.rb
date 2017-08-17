module Jobba::Utils

  # Represent time as an integer number of us since epoch
  # (helps avoid redis precision issues)
  def self.time_to_usec_int(time)
    case time
    when ::Time
      time.strftime("%s%6N").to_i
    when Float
      # assuming that time is the number of seconds since epoch
      # to avoid precision issues, convert to a string, remove
      # the decimal, and convert back to an integer
      sprintf("%0.6f", time.to_f).gsub(/\./,'').to_i
    when Integer
      time
    when String
      time.to_i
    end
  end

  def self.time_from_usec_int(int)
    Jobba::Time.at(int / 1000000, int % 1000000)
  end

  def self.temp_key
    "temp:#{SecureRandom.hex(10)}"
  end

  def self.limited_count(nonlimited_count:, offset:, limit:)
    raise(ArgumentError, "`limit` cannot be negative") if !limit.nil? && limit < 0
    raise(ArgumentError, "`offset` cannot be negative") if !offset.nil? && offset < 0

    # If we get a count of an array or set that doesn't take into account
    # specified offsets and limits (what we call a `nonlimited_count`, but
    # we need the count to effectively have been done with an offset and
    # limit, this method calculates that limited count.
    #
    # This can happen when it is more efficient to calculate an unlimited
    # count and then limit it after the fact.
    #
    # E.g.
    #
    # Get count of
    #   array = [a b c d e f g]
    # where
    #   offset = 4
    #   limit = 5
    #
    # nonlimited_count = 7
    #
    # The limited array includes the highlighted (^) elements
    #   array = [a b c d e f g]
    #                    ^ ^ ^ ^ ^
    # Element `e` is the first element indicated by an offset of 4.  The
    # limit of 5 then causes us to take the rest of the elements in the array.
    # The limit here is effectively 3 since there are only 3 elements left.
    #
    # So the limited_count is 3.

    first_position_counted = offset || 0

    # The `min` here is to make sure we don't go beyond the end of the array.  The `- 1`
    # is because we are getting a zero-indexed position from a count.
    last_position_counted = [first_position_counted + (limit || nonlimited_count), nonlimited_count].min - 1

    # Guard against first position being after last position by forcing min of 0
    [last_position_counted - first_position_counted + 1, 0].max
  end

end
