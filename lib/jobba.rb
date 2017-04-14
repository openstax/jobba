require 'forwardable'
require 'securerandom'

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
    @redis ||= Redis::Namespace.new(
      configuration.namespace,
      redis: Redis.new(configuration.redis_options || {})
    )
  end

end
