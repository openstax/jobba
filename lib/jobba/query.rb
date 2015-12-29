class Jobba::Query

  def self.all
    new
  end

  # TODO handle the OR wheres: "state: [:queued, :unqueued]"

  def where(options)
    options.each do |option_key, option_value|
      @sets.push(
        case option_key
        when :state
          state_set(option_value)
        when :job_name
          Set.new(key: "job_name:#{option_value}")
        when :for_arg
          Set.new(key: "for_arg:#{option_value}")
        when /.*_at/
          timestamp_set(option_key, option_value)


        else
          raise ArgumentError, "#{option_key} is not a valid key in a Jobba `where` call"
        end
      )

    end
  end

  def method_missing(method_name, *args)
    # get_dynamic_variable(method_name) || super
  end

  def respond_to?(method_name)
    # has_dynamic_variable?(method_name) || super
  end

  protected

  attr_accessor :sets

  def run

    sets.each do |set|

    end
  end

  def initialize
    @sets = []
  end




  def timestamp_set(timestamp_name, options)
    min, max =
      case options
      when Array
        if options.length != 2
          raise ArgumentError, "Wrong number of array entries for '#{timestamp_name}'."
        end

        options_value[0], option_value[1]
      when Hash
        options[:after], options[:before]
      else
        raise ArgumentError,
              "#{option_value} is not a valid value for a " +
              "#{option_key} key in a Jobba `where` call"
      end

    Set.new(key: "#{option_key}", min: min, max: max)
  end

  def state_set(state)
    Set.new(key: option_value)
  end

  class Set
    attr_reader :key, :min, :max

    def initialize(key:, min: nil, max: nil)
      @key = Jobba::Configuration.namespace + ":" + key
      @min = min
      @max = max
    end
  end

  # Jobba.queued # those jobs that are currently queued
  # Jobba.queued(between: [t1, t2]) # those jobs that were queued between the times
  #   # is this queued_at(betweent: ...)?  or queued_between(t1,t2)
  # Jobba.queued(between: [t1, t2]).kill # kill all jobs queued in that time range
  # Jobba.queued(after: t1).completed(before: t2)
  # Jobba.job_named('job_name')
  # Jobba.job_named('job_name').failed
  # Jobba.failed.job_named('job_name')
  # Jobba.succeeded.duration.average
  # Jobba.succeeded(before: 1.week.ago).clear
  # Jobba.completed
  # Jobba.incomplete
  # Jobba.failed.time_descending
  # Jobba.for_arg(some_argument)  # job needs to note the status itself
  # Jobba.all
  # Jobba.job_names  # return all known job names

  # ----------

  # Jobba.where(state: :queued).where(job_name: 'blah')
  # Jobba.where(state: [:queued, :unqueued])

end
