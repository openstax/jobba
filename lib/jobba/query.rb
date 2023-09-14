require 'jobba/clause'
require 'jobba/id_clause'
require 'jobba/clause_factory'

class Jobba::Query
  include Jobba::Common

  attr_reader :_limit, :_offset

  def where(options)
    options.each do |kk, vv|
      clauses.push(Jobba::ClauseFactory.new_clause(kk, vv))
    end

    self
  end

  def limit(number)
    @_limit = number
    @_offset ||= 0
    self
  end

  def offset(number)
    @_offset = number
    self
  end

  def count
    _run(CountStatuses.new(self))
  end

  def empty?
    count == 0
  end

  # At the end of a chain of `where`s, the user will call methods that expect
  # to run on the result of the executed `where`s.  So if we don't know what
  # the method is, execute the `where`s and pass the method to its output.

  def method_missing(method_name, *args, &block)
    if Jobba::Statuses.instance_methods.include?(method_name)
      run.send(method_name, *args, &block)
    else
      super
    end
  end

  def respond_to?(method_name)
    Jobba::Statuses.instance_methods.include?(method_name) || super
  end

  def run
    _run(GetStatuses.new(self))
  end

  protected

  attr_accessor :clauses

  def initialize
    @clauses = []
  end

  class Operations
    attr_reader :query, :redis

    def initialize(query)
      @query = query
      @redis = query.redis
    end

    # Standalone method that gives the final result when the query is one clause
    def handle_single_clause(_clause)
      raise 'AbstractMethod'
    end

    # When the query is multiple clauses, this method is called on the final set
    # that represents the ANDing of all clauses.  It is called inside a `redis.multi`
    # block.
    def multi_clause_last_redis_op(_result_set)
      raise 'AbstractMethod'
    end

    # Called on the output from the redis multi block for multi-clause queries.
    def multi_clause_postprocess(_redis_output)
      raise 'AbstractMethod'
    end
  end

  class GetStatuses < Operations
    def handle_single_clause(clause)
      ids = clause.result_ids(limit: query._limit, offset: query._offset)
      Jobba::Statuses.new(ids)
    end

    def multi_clause_last_redis_op(result_set)
      start = query._offset || 0
      stop = query._limit.nil? ? -1 : start + query._limit - 1
      redis.zrange(result_set, start, stop)
    end

    def multi_clause_postprocess(ids)
      Jobba::Statuses.new(ids)
    end
  end

  class CountStatuses < Operations
    def handle_single_clause(clause)
      clause.result_count(limit: query._limit, offset: query._offset)
    end

    def multi_clause_last_redis_op(result_set)
      redis.zcard(result_set)
    end

    def multi_clause_postprocess(redis_output)
      Jobba::Utils.limited_count(nonlimited_count: redis_output, offset: query._offset, limit: query._limit)
    end
  end

  def _run(operations)
    raise ArgumentError, '`limit` must be set if `offset` is set', caller if _limit.nil? && !_offset.nil?

    load_default_clause if clauses.empty?

    if clauses.one?
      # We can make specialized calls that don't need intermediate copies of sets
      # to be made (which are costly)
      operations.handle_single_clause(clauses.first)
    else
      # Each clause in a query is converted to a sorted set (which may be filtered,
      # e.g. in the case of timestamp clauses) and then the sets are successively
      # intersected.
      #
      # Different users of this method have different uses for the final "working"
      # set.  Because we want to bundle all of the creations and intersections of
      # clause sets into one call to Redis (via a `multi` block), we have users
      # of this method provide a final block to run on the working set within
      # Redis (and within the `multi` call) and then another block to run on
      # the output of the first block.
      #
      # This code also works for the single clause case, but it is less efficient

      multi_result = transaction do |trn|
        working_set = nil

        clauses.each do |clause|
          clause_set = clause.to_new_set

          if working_set.nil?
            working_set = clause_set
          else
            trn.zinterstore(working_set, [working_set, clause_set], weights: [0, 0])
            trn.del(clause_set)
          end
        end

        # This is later accessed as `multi_result[-2]` since it is the second to last output
        operations.multi_clause_last_redis_op(working_set)

        trn.del(working_set)
      end

      operations.multi_clause_postprocess(multi_result[-2])
    end
  end

  def load_default_clause
    where(state: Jobba::State::ALL.collect(&:name))
  end
end
