class Jobba::Statuses
  include Jobba::Common
  extend Forwardable

  attr_reader :ids

  def to_a
    load.dup
  end

  def_delegators :@ids, :empty?

  def_delegators :load, :any?, :none?, :all?, :count, :length, :size,
                 :map, :collect, :reduce, :inject, :first, :last

  def select!(&block)
    modify!(:select!, &block)
  end

  def reject!(&block)
    modify!(:reject!, &block)
  end

  def delete_all
    if any?(&:incomplete?)
      raise(Jobba::NotCompletedError,
            "This status cannot be deleted because it isn't complete.  Use " \
            '`delete_all!` if you want to delete anyway.')
    end

    delete_all!
  end

  def delete_all!
    load

    # preload prior attempts because loading them is not `multi`-friendly
    @cache.each { |cache| cache.prior_attempts.each(&:prior_attempts) }

    transaction do
      @cache.each(&:delete!)
    end
    @cache = []
    @ids = []
  end

  def request_kill_all!
    load
    transaction do
      @cache.each(&:request_kill!)
    end
  end

  def multi(&block)
    load
    transaction do
      @cache.each { |status| block.call(status, redis) }
    end
  end

  protected

  def load
    @cache ||= get_all!
  end

  def get_all!
    id_keys = @ids.collect { |id| "id:#{id}" }

    raw_statuses = redis.pipelined do |pipe|
      id_keys.each do |key|
        pipe.hgetall(key)
      end
    end

    raw_statuses.reject!(&:empty?)

    raw_statuses.collect do |raw_status|
      Jobba::Status.new(raw: raw_status)
    end
  end

  def modify!(method, &block)
    raise Jobba::NotImplemented unless block_given?

    load
    if @cache.send(method, &block).nil?
      nil
    else
      @ids = @cache.collect(&:id)
      self
    end
  end

  def initialize(*ids)
    @ids = [ids].flatten.compact
    @cache = nil
  end
end
