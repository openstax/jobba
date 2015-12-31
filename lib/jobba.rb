require "redis"
require "redis-namespace"

require "jobba/version"
require "jobba/exceptions"
require "jobba/time"
require "jobba/utils"
require "jobba/configuration"
require "jobba/common"
require "jobba/state"
require "jobba/status"
require "jobba/statuses"
require "jobba/query"

module Jobba

  def self.where(*args)
    Query.new.where(*args)
  end

  def self.all
    Query.new.all
  end

  def self.count
    Query.new.count
  end

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.redis
    @redis ||= Redis::Namespace.new(
      configuration.namespace,
      redis: Redis.new(configuration.redis_options || {})
    )
  end

end
