class Jobba::Configuration

  attr_accessor :redis_options
  attr_accessor :namespace

  def initialize
    @redis_options = {}
    @namespace = "jobba"
  end
end
