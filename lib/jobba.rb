require 'delegate'
require 'forwardable'
require 'securerandom'

require 'redis'
require 'redis-namespace'

require 'jobba/version'
require 'jobba/exceptions'
require 'jobba/time'
require 'jobba/utils'
require 'jobba/configuration'
require 'jobba/common'
require 'jobba/redis_with_expiration'
require 'jobba/state'
require 'jobba/status'
require 'jobba/statuses'
require 'jobba/query'

module Jobba
  class << self
    extend Forwardable

    def_delegators Jobba::Status, :all, :where, :find_by, :create, :create!, :find, :find!
  end

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.redis
    return @transaction if @transaction

    @redis ||= Jobba::RedisWithExpiration.new(
      Redis::Namespace.new(
        configuration.namespace,
        redis: Redis.new(configuration.redis_options || {})
      )
    )
  end

  def self.transaction(&block)
    return @transaction unless block_given?

    if @transaction
      block.call(@transaction)
    else
      redis.multi do |trn|
        @transaction = trn
        begin
          block.call(@transaction)
        ensure
          @transaction = nil
        end
      end
    end
  end

  def self.cleanup(seconds_ago: 60 * 60 * 24 * 30 * 12, batch_size: 1000)
    start_time = Jobba::Time.now
    delete_before = start_time - seconds_ago

    jobs_count = 0
    loop do
      jobs = where(recorded_at: { before: delete_before }).limit(batch_size).to_a
      jobs.each(&:delete!)

      num_jobs = jobs.size
      jobs_count += num_jobs
      break if jobs.size < batch_size
    end
    jobs_count
  end

  # Clears the whole shebang!  USE WITH CARE!
  def self.clear_all_jobba_data!
    cleanup(seconds_ago: 0)
  end
end
