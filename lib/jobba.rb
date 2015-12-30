require "redis"
require "redis-namespace"

require "jobba/version"
require "jobba/configuration"
require "jobba/common"
require "jobba/state"
require "jobba/status"
require "jobba/statuses"
require "jobba/query"

module Jobba

  # def self.all
  #   job_ids.map { |id| find!(id) }
  #   # can maybe count
  # end

  # (Jobba::State::LIST + %w(completed incomplete)).each do |state|
  #   define_singleton_method("#{state}") do
  #     all.select{|job| job.send("#{state}?")}
  #   end
  # end

  # TODO add some query routines

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

# "kill requested" isn't really a state but rather a condition -- while kill
# is requested the job is still in some other state (eg still "working").
# only when it is actually killed does it change states (to "killed")

# TODO would be nice to have some tests that test scale

  # def queued

  # end


  def self.redis
    @redis ||= Redis::Namespace.new(
      configuration.namespace,
      redis: Redis.new(configuration.redis_options || {})
    )
  end


end
