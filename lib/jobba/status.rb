require 'json'
require 'ostruct'

module Jobba
  class Status

    include Jobba::Common

    def self.create!
      create(state: State::UNQUEUED)
    end

    # Finds the job with the specified ID and returns it.  If no such ID
    # exists in the store, returns a job with 'unknown' state and sets it
    # in the store
    def self.find!(id)
      find(id) || create(id: id)
    end

    # Finds the job with the specified ID and returns it.  If no such ID
    # exists in the store, returns nil.
    def self.find(id)
      if (hash = raw_redis_hash(id))
        new(raw: hash)
      else
        nil
      end
    end

    def self.local_attrs
      %w(id state progress errors data kill_requested_at job_name job_args attempt) +
      State::ALL.collect(&:timestamp_name)
    end

    def reload!
      @json_encoded_attrs = self.class.raw_redis_hash(id)
      clear_attrs
      self
    end

    # If the attributes are nil, the attribute accessors lazily parse their values
    # from the JSON retrieved from redis.  That way there's no parsing that isn't used.
    # As an extra step, convert state names into State objects.

    local_attrs.each do |attribute|
      class_eval <<-eoruby
        def #{attribute}
          @#{attribute} ||= load_from_json_encoded_attrs('#{attribute}')
        end

        protected

        attr_writer :#{attribute}
      eoruby
    end

    State::ENTERABLE.each do |state|
      define_method("#{state.name}!") do
        redis.multi do
          if state == State::STARTED && did_start?
            restart!
          elsif state != self.state
            move_to_state!(state)
          end
        end

        self
      end
    end

    State::ALL.each do |state|
      define_method("#{state.name}?") do
        state == self.state
      end
    end

    def completed?
      failed? || succeeded?
    end

    def incomplete?
      !completed?
    end

    def did_start?
      !self.started_at.nil?
    end

    def request_kill!
      time, usec_int = now
      if redis.hsetnx(job_key, :kill_requested_at, usec_int)
        @kill_requested_at = time
      end
    end

    def kill_requested?
      !kill_requested_at.nil?
    end

    def set_progress(at, out_of = nil)
      progress = compute_fractional_progress(at, out_of)
      set(progress: progress)
    end

    def set_job_name(job_name)
      raise ArgumentError, "`job_name` must not be blank" if job_name.nil? || job_name.empty?
      raise StandardError, "`job_name` can only be set once" if !self.job_name.nil?

      redis.multi do
        set(job_name: job_name)
        redis.sadd(job_name_key, id)
      end
    end

    def add_job_arg(arg_name, arg)
      raise ArgumentError, "`arg_name` must not be blank" if arg_name.nil? || arg_name.empty?
      raise ArgumentError, "`arg` must not be blank" if arg.nil? || arg.empty?

      redis.multi do
        self.job_args[arg_name.to_sym] = arg
        redis.hset(job_args_key, arg_name, arg)
        redis.sadd(job_arg_key(arg), id)
      end
    end

    # def add_error(error:)
    # maybe errors should be free form -- pass in whatever keys and values you want (client specific)
    # we could supplement an error with a timestamp

    # def add_error(error, options = { })
    #   options = { is_fatal: false }.merge(options)
    #   @errors << { is_fatal: options[:is_fatal],
    #                code: error.code,
    #                message: error.message,
    #                data: error.data }
    #   set(errors: @errors)
    # end

    def save(data)
      normalized_data = JSON.parse(data.to_json, quirks_mode: true)
      set(data: normalized_data)
    end

    def delete
      completed? ?
        delete! :
        raise(NotCompletedError, "This status cannot be deleted because it " \
                                 "isn't complete.  Use `delete!` if you want to " \
                                 "delete anyway.")
    end

    def delete!
      delete_in_redis!
      delete_locally!
    end

    def prior_attempts
      [*0..attempt-1].collect{|ii| self.class.find!("#{id}:#{ii}")}
    end

    protected

    def self.create(attrs)
      new(attrs.merge!(persist: true))
    end

    def self.raw_redis_hash(id)
      main_hash, job_args_hash = redis.multi do
        redis.hgetall(job_key(id))
        redis.hgetall(job_args_key(id))
      end

      return nil if main_hash.empty?

      main_hash['job_args'] = job_args_hash.to_json if !job_args_hash.nil?
      main_hash
    end

    def restart!
      # Identify the values we want the restarted status to have, archive
      # the attempt (clears out redis and local for this status), then
      # set the restarted values

      restarted_values = {
        id: id,
        attempt: attempt+1,
        recorded_at: recorded_at,
        queued_at: queued_at,
        progress: 0,
        errors: [],
        job_name: job_name,
        job_args: job_args
      }

      archive_attempt!

      set(restarted_values)
      move_to_state!(State::STARTED)
    end

    def archive_attempt!
      archived_job_key = job_key(attempt)
      redis.rename(job_key, archived_job_key)
      redis.hset(archived_job_key, :id, "#{id}:#{attempt}".to_json)
      delete_locally!
    end

    def move_to_state!(state)
      set(state: state, state.timestamp_name_key => Jobba::Time.now)
    end

    def initialize(attrs = {})
      # If we get a raw hash, don't parse the attributes until they are requested

      @json_encoded_attrs = attrs[:raw]

      if @json_encoded_attrs.nil? || @json_encoded_attrs.empty?
        @id       = attrs[:id]       || attrs['id']       || SecureRandom.uuid
        @state    = attrs[:state]    || attrs['state']    || State::UNKNOWN
        @progress = attrs[:progress] || attrs['progress'] || 0
        @errors   = attrs[:errors]   || attrs['errors']   || []
        @data     = attrs[:data]     || attrs['data']     || {}
        @attempt  = attrs[:attempt]  || attrs['attempt']  || 0

        if attrs[:persist]
          redis.multi do
            set({
              id: id,
              progress: progress,
              errors: errors,
              attempt: attempt
            })
            move_to_state!(state)
          end
        end
      end
    end

    def load_from_json_encoded_attrs(attribute_name)
      json = (@json_encoded_attrs || {})[attribute_name]
      attribute = json.nil? ? nil : JSON.parse(json, quirks_mode: true)

      case attribute_name
      when 'state'
        State.from_name(attribute)
      when /.*_at/
        attribute.nil? ? nil : Jobba::Utils.time_from_usec_int(attribute.to_i)
      when 'job_args'
        OpenStruct.new(attribute)
      else
        attribute
      end
    end

    def set(incoming_hash)
      # in case the ID isn't set but is in the hash, set locally so other
      # commands can use it
      self.id = incoming_hash[:id] || id

      apply_consistency_rules!(incoming_hash)

      set_hash_in_redis(incoming_hash)
      set_state_in_redis(incoming_hash)
      set_state_timestamps_in_redis(incoming_hash)

      set_hash_locally(incoming_hash)
    end

    def apply_consistency_rules!(hash)
      hash[:progress] = 1.0 if hash[:state] == State::SUCCEEDED
    end

    def set_hash_in_redis(hash)
      redis_key_value_array =
        hash.to_a.flat_map do |kv_array|
          key = kv_array[0]
          value = kv_array[1]
          value = Jobba::Utils.time_to_usec_int(value) if value.is_a?(::Time)

          [key, value.to_json]
        end

      Jobba.redis.hmset(job_key, *redis_key_value_array)
    end

    def set_state_in_redis(hash)
      return unless hash[:state]
      redis.srem(state.name, id) unless state.nil? # leave old state if set
      redis.sadd(hash[:state].name, id)            # enter new state
    end

    def set_state_timestamps_in_redis(hash)
      timestamp_names = hash.keys & State::ALL_TIMESTAMP_SYMBOLS

      timestamp_names.each do |timestamp_name|
        usec_int = Utils.time_to_usec_int(hash[timestamp_name])
        redis.zadd(timestamp_name, usec_int, id)
      end
    end

    def set_hash_locally(hash)
      hash.each{ |key, value| self.send("#{key}=", value) }
    end

    def delete_in_redis!
      redis.multi do
        redis.del(job_key)

        State::ALL.each do |state|
          redis.srem(state.name, id)
          redis.zrem(state.timestamp_name, id)
        end

        redis.srem(job_name_key, id)

        redis.del(job_args_key)
        job_args.marshal_dump.values.each do |arg|
          redis.srem(job_arg_key(arg), id)
        end
      end

      prior_attempts.each(&:delete!)
    end

    def delete_locally!
      clear_attrs
      @json_encoded_attrs = nil
    end

    def clear_attrs
      self.class.local_attrs.each{|aa| send("#{aa}=",nil)}
    end

    def job_name_key
      "job_name:#{job_name}"
    end

    def job_key(attempt=nil)
      self.class.job_key(id, attempt)
    end

    def self.job_key(id, attempt=nil)
      raise(ArgumentError, "`id` cannot be nil") if id.nil?
      attempt.nil? ? "id:#{id}" : "id:#{id}:#{attempt}"
    end

    def job_args_key
      self.class.job_args_key(id)
    end

    def self.job_args_key(id)
      raise(ArgumentError, "`id` cannot be nil") if id.nil?
      "job_args:#{id}"
    end

    def job_arg_key(arg)
      "job_arg:#{arg}"
    end

    def job_errors_key(id)
      raise(ArgumentError, "`id` cannot be nil") if id.nil?
      "#{id}:errors"
    end

    def compute_fractional_progress(at, out_of)
      if at.nil?
        raise ArgumentError, "Must specify at least `at` argument to `progress` call"
      elsif at < 0
        raise ArgumentError, "progress cannot be negative (at=#{at})"
      elsif out_of && out_of < at
        raise ArgumentError, "`out_of` must be greater than `at` in `progress` calls"
      elsif out_of.nil? && (at < 0 || at > 1)
        raise ArgumentError, "If `out_of` not specified, `at` must be in the range [0.0, 1.0]"
      end

      at.to_f / (out_of || 1).to_f
    end

    def now
      [time = Jobba::Time.now, Utils.time_to_usec_int(time)]
    end

  end
end
