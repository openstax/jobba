require 'json'

module Jobba
  class Status

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
      ( result = redis.hgetall(job_key(id)) ).empty? ? nil : new(raw: result)
    end

    # If the attributes are nil, the attribute accessors lazily parse their values
    # from the JSON retrieved from redis.  That way there's no parsing that isn't used.
    # As an extra step, convert state names into State objects.

    (
      %w(id state progress errors data kill_requested_at) +
      State::ALL.collect(&:timestamp_name)
    )
    .each do |attribute|
      class_eval <<-eoruby
        def #{attribute}
          @#{attribute} ||= load_from_json_encoded_attrs('#{attribute}')
        end

        protected

        attr_writer :#{attribute}
      eoruby
    end

    State::ALL.each do |state|
      define_method("#{state.name}!") do
        return if state == self.state

        redis.multi do
          leave_current_state!
          enter_state!(state)
        end
      end

      define_method("#{state.name}?") do
        state == self.state
        # redis.sismember(state.name, id)
      end
    end

    def completed?
      failed? || succeeded?
    end

    def incomplete?
      !completed?
    end

    def request_kill!
      time = Time.now.to_f
      if redis.hsetnx(job_key, :kill_requested_at, time)
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

    # def add_error(error, options = { })
    #   options = { is_fatal: false }.merge(options)
    #   @errors << { is_fatal: options[:is_fatal],
    #                code: error.code,
    #                message: error.message,
    #                data: error.data }
    #   set(errors: @errors)
    # end

    def save(data)
      set(data: data)
    end

    protected

    def self.create(attrs)
      new(attrs.merge!(persist: true))
    end

    def leave_current_state!
      redis.srem(state.name, id)
    end

    def enter_state!(state)
      time = Time.now.to_f
      set(state: state.name, state.timestamp_name => time)
      self.state = state
      self.send("#{state.timestamp_name}=",time)
      redis.zadd(state.timestamp_name, time, id)
      redis.sadd(state.name, id)
    end

    def initialize(attrs = {})
      # If we get a raw hash, don't parse the attributes until they are requested

      if (@json_encoded_attrs = attrs[:raw])
        @json_encoded_attrs['data'] ||= "{}"
      else
        @id       = attrs[:id]       || attrs['id']       || SecureRandom.uuid
        @state    = attrs[:state]    || attrs['state']    || State::UNKNOWN
        @progress = attrs[:progress] || attrs['progress'] || 0
        @errors   = attrs[:errors]   || attrs['errors']   || []
        @data     = attrs[:data]     || attrs['data']     || {}

        if attrs[:persist]
          redis.multi do
            set({
              id: id,
              progress: progress,
              errors: errors
            })
            enter_state!(state)
          end
        end
      end
    end

    def load_from_json_encoded_attrs(attribute_name)
      json = (@json_encoded_attrs || {})[attribute_name]
      attribute = json.nil? ? nil : JSON.parse(json, quirks_mode: true)
      'state' == attribute_name ? State.from_name(attribute) : attribute
    end

    def set(incoming_hash)
      apply_consistency_rules!(incoming_hash)
      set_hash_locally(incoming_hash)
      set_hash_in_redis(incoming_hash)
    end

    def apply_consistency_rules!(hash)
      hash[:progress] = 1.0 if hash[:state] == State::SUCCEEDED
    end

    def set_hash_locally(hash)
      hash.each{ |key, value| self.send("#{key}=", value) }
    end

    def set_hash_in_redis(hash)
      redis_key_value_array =
        hash.to_a
            .collect{|kv_array| [kv_array[0], kv_array[1].to_json]}
            .flatten(1)

      Jobba.redis.hmset(job_key, *redis_key_value_array)
    end

    def job_key
      self.class.job_key(@id)
    end

    def self.job_key(id)
      raise(ArgumentError, "`id` cannot be nil") if id.nil?
      "id:#{id}"
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

    # For convenience

    def redis;      Jobba.redis; end
    def self.redis; Jobba.redis; end

  end
end
