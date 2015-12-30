class Jobba::Statuses

  include Jobba::Common

  attr_reader :ids

  def all
    id_keys = @ids.collect{|id| "id:#{id}"}
    raw_statuses = redis.mget(id_keys)
    raw_statuses.collect{|raw_status| Jobba::Status.new(raw: raw_status)}
  end

  protected

  def initialize(ids)
    @ids = ids || []
  end

end
