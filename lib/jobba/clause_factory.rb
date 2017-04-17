require 'jobba/clause'

class Jobba::ClauseFactory

  def self.new_clause(key, value)
    if value.nil?
      raise ArgumentError, "Nil search criteria are not currently " \
                           "accepted in a Jobba `where` call", caller
    end

    case key.to_sym
    when :state
      state_clause(value)
    when :job_name
      Jobba::Clause.new(prefix: "job_name", suffixes: value)
    when :job_arg
      Jobba::Clause.new(prefix: "job_arg", suffixes: value)
    when :provider_job_id
      Jobba::Clause.new(prefix: "provider_job_id", suffixes: value)
    when :id
      Jobba::IdClause.new(value)
    when /.*_at/
      timestamp_clause(key, value)
    else
      raise ArgumentError, "#{key} is not a valid key in a Jobba `where` call", caller
    end
  end

  def self.timestamp_clause(timestamp_name, options)
    validate_timestamp_name!(timestamp_name)

    min, max =
      case options
      when Array
        if options.length != 2
          raise ArgumentError, "Wrong number of array entries for '#{timestamp_name}'.", caller
        end

        [options[0], options[1]]
      when Hash
        [options[:after], options[:before]]
      else
        raise ArgumentError,
              "#{option_value} is not a valid value for a " +
              "#{option_key} key in a Jobba `where` call",
              caller
      end

    min = Jobba::Utils.time_to_usec_int(min)
    max = Jobba::Utils.time_to_usec_int(max)

    Jobba::Clause.new(keys: timestamp_name, min: min, max: max)
  end

  def self.state_clause(state)
    state = [state].flatten.collect { |ss|
      case ss
      when :completed
        Jobba::State::COMPLETED.collect(&:name)
      when :incomplete
        Jobba::State::INCOMPLETE.collect(&:name)
      else
        ss
      end
    }.uniq

    validate_state_name!(state)
    Jobba::Clause.new(keys: state)
  end

  def self.validate_state_name!(state_name)
    [state_name].flatten.each do |name|
      if Jobba::State::ALL.none?{|state| state.name == name.to_s}
        raise ArgumentError, "'#{name}' is not a valid state name.", caller
      end
    end
  end

  def self.validate_timestamp_name!(timestamp_name)
    if Jobba::State::ALL.none?{|state| state.timestamp_name == timestamp_name.to_s}
      raise ArgumentError, "'#{timestamp_name}' is not a valid timestamp.", caller
    end
  end

end
