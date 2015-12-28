require "jobba/version"
require "jobba/configuration"
require "jobba/status"
require "jobba/statuses"

module Jobba

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

end
