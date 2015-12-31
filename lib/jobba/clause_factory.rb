require 'jobba/clause'

class Jobba::ClauseFactory

  def self.new_clause(key, value)
    case key
    when :state
      state_clause(value)
    when :job_name
      Jobba::Clause.new(key: "job_name:#{value}")
    when :for_arg
      Jobba::Clause.new(key: "for_arg:#{value}")
    when /.*_at/
      timestamp_clause(key, value)
    else
      raise ArgumentError, "#{key} is not a valid key in a Jobba `where` call"
    end
  end

  protected

  def self.timestamp_clause(timestamp_name, options)
    validate_timestamp_name!(timestamp_name)

    min, max =
      case options
      when Array
        if options.length != 2
          raise ArgumentError, "Wrong number of array entries for '#{timestamp_name}'."
        end

        [options[0], options[1]]
      when Hash
        [options[:after], options[:before]]
      else
        raise ArgumentError,
              "#{option_value} is not a valid value for a " +
              "#{option_key} key in a Jobba `where` call"
      end

    min = Jobba::Utils.time_to_usec_int(min)
    max = Jobba::Utils.time_to_usec_int(max)

    Jobba::Clause.new(key: timestamp_name, min: min, max: max)
  end

  def self.state_clause(state)
    validate_state_name!(state)
    Jobba::Clause.new(key: state)
  end

  def self.validate_state_name!(state_name)
    [state_name].flatten.each do |name|
      if Jobba::State::ALL.none?{|state| state.name == name.to_s}
        raise ArgumentError, "'#{state}' is not a valid timestamp."
      end
    end
  end

  def self.validate_timestamp_name!(timestamp_name)
    if Jobba::State::ALL.none?{|state| state.timestamp_name == timestamp_name.to_s}
      raise ArgumentError, "'#{timestamp_name}' is not a valid timestamp."
    end
  end

end
