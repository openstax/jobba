class Jobba::Statuses

  include Jobba::Common
  extend Forwardable

  attr_reader :ids

  def all
    load
  end

  def_delegator :@ids, :empty?
  def_delegators :all, :first, :any?, :none?, :all?, :each, :each_with_index,
                       :map, :collect, :select, :count

  def delete
    if any?(&:incomplete?)
      raise(Jobba::NotCompletedError,
            "This status cannot be deleted because it isn't complete.  Use " \
            "`delete!` if you want to delete anyway.")
    end

    delete!
  end

  def delete!
    load
    redis.multi do
      @cache.each(&:delete!)
    end
    @cache = []
    @ids = []
  end

  def request_kill!
    load
    redis.multi do
      @cache.each(&:request_kill!)
    end
  end

  def multi(&block)
    load
    redis.multi do
      @cache.each{|status| block.call(status, redis)}
    end
  end

  protected

  def load
    @cache ||= get_all!
  end

  def get_all!
    id_keys = @ids.collect{|id| "id:#{id}"}

    raw_statuses = redis.pipelined do
      id_keys.each do |key|
        redis.hgetall(key)
      end
    end

    raw_statuses.collect do |raw_status|
      Jobba::Status.new(raw: raw_status)
    end
  end

  def initialize(*ids)
    @ids = [ids].flatten.compact
    @cache = nil
  end

end
