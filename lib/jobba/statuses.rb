class Jobba::Statuses

  include Jobba::Common
  extend Forwardable

  attr_reader :ids

  def all
    id_keys = @ids.collect{|id| "id:#{id}"}

    raw_statuses = redis.pipelined do
      id_keys.each do |key|
        redis.hgetall(key)
      end
    end

    raw_statuses.collect{|raw_status| Jobba::Status.new(raw: raw_status)}
  end

  def_delegator :@ids, :empty?
  def_delegators :all, :first, :any?, :none?, :all?, :each, :each_with_index,
                       :map, :collect, :select

  protected

  def initialize(*ids)
    @ids = [ids].flatten.compact
  end

end
