module Jobba
  module Utils

    # Represent time as an integer number of us since epoch
    # (helps avoid redis precision issues)
    def self.time_to_usec_int(time)
      case time
      when Time
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
      Time.at(int / 1000000, int % 1000000)
    end

  end
end
