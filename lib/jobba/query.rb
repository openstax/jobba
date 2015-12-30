class Jobba::Query

  include Jobba::Common

  # def self.all
  #   new
  # end

  # TODO handle the OR wheres: "state: [:queued, :unqueued]"

  def where(options)
    options.each do |option_key, option_value|
      @clauses.push(
        case option_key
        when :state
          state_clause(option_value)
        when :job_name
          Clause.new(key: "job_name:#{option_value}")
        when :for_arg
          Clause.new(key: "for_arg:#{option_value}")
        when /.*_at/
          timestamp_clause(option_key, option_value)


        else
          raise ArgumentError, "#{option_key} is not a valid key in a Jobba `where` call"
        end
      )

    end

    self
  end

  # At the end of a chain of `where`s, the user will call methods that expect
  # to run on the result of the executed `where`s.  So if we don't know what
  # the method is, execute the `where`s and pass the method to its output.

  def method_missing(method_name, *args)
    if Jobba::Statuses.instance_methods.include?(method_name)
      run.send(method_name, *args)
    else
      super
    end
  end

  def respond_to?(method_name)
    Jobba::Statuses.instance_methods.include?(method_name) || super
  end

  protected

  attr_accessor :clauses

  def run

    # TODO PUT IN MULTI BLOCKS WHERE WE CAN!
    # TODO implement where(state: [:queued, :working])

    working_set = nil

    clauses.each_with_index do |clause, ii|
      clause_set = clause.to_new_set

      if working_set.nil?
        working_set = clause_set
      else
        redis.zinterstore(working_set, [working_set, clause_set], weights: [0, 0])
        redis.del(clause_set)
      end
    end

    ids = redis.zrange(working_set, 0, -1)
    redis.del(working_set)

    Jobba::Statuses.new(ids)
  end

  def initialize
    @clauses = []
  end


  def timestamp_clause(timestamp_name, options)
    if Jobba::State::ALL.none?{|state| state.timestamp_name == timestamp_name.to_s}
      raise ArgumentError, "'#{timestamp_name}' is not a valid timestamp."
    end

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

    min = normalize_time(min)
    max = normalize_time(max)

    Clause.new(key: timestamp_name, min: min, max: max)
  end

  def normalize_time(time)
    time = time.to_f if time.is_a?(Time)
    time = time.to_s if time.is_a?(Float)
    time
  end

  def state_clause(state)
    Clause.new(key: state)
  end

  class Clause
    attr_reader :key, :min, :max

    include Jobba::Common

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

      redis.zunionstore(new_key, [key])
      redis.zremrangebyscore(new_key, '-inf', min) unless min.nil?
      redis.zremrangebyscore(new_key, max, '+inf') unless max.nil?

      new_key
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
