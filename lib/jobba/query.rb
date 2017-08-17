require 'jobba/clause'
require 'jobba/id_clause'
require 'jobba/clause_factory'

class Jobba::Query

  include Jobba::Common

  attr_reader :_limit, :_offset

  def where(options)
    options.each do |kk,vv|
      clauses.push(Jobba::ClauseFactory.new_clause(kk,vv))
    end

    self
  end

  def limit(number)
    @limit = number
    @offset ||= 0
    self
  end

  def offset(number)
    @offset = number
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

  # class RunBlocks
  #   attr_reader :multi_clause_block, :output_block, :single_clause_block

  #   def initialize(single_clause_block:, multi_clause_block:, output_block: nil)
  #     @single_clause_block = single_clause_block
  #     @multi_clause_block = multi_clause_block
  #     @output_block = output_block || ->(input) { input }
  #   end
  # end

  # GET_STATUSES = RunBlocks.new(
  #   single_clause_block: ->(clause, options={}) {
  #     clause.result_ids(limit: options[:limit], offset: options[:offset])
  #   },
  #   multi_clause_block: ->(working_set, redis, options={}) {
  #     start = options[:offset] || 0
  #     stop = options[:limit].nil? ? -1 : start + options[:limit]
  #     redis.zrange(working_set, start, stop)
  #   },
  #   output_block: ->(ids) {
  #     Jobba::Statuses.new(ids)
  #   }
  # )

  # COUNT_STATUSES = RunBlocks.new(
  #   single_clause_block: ->(clause, options={}) {
  #     clause.result_count(limit: options[:limit], offset: options[:offset])
  #   },
  #   multi_clause_block: ->(working_set, redis, options={}) {
  #     redis.zcard(working_set)
  #   }
  #   output_block: ->(nonlimited_count, options={}) {
  #     start = options[:offset] || 0
  #     stop = [(options[:limit] || count), count].min
  #     stop - start
  #   }
  # )

  class Operations
    attr_reader :query, :redis

    def initialize(query)
      @query = query
      @redis = query.redis
    end

    def handle_single_clause(clause)
      raise "AbstractMethod"
    end

    def handle_result_set(result_set)
      raise "AbstractMethod"
    end

    def postprocess_output(output)
      output
    end
  end

  class GetStatuses < Operations
    def handle_single_clause(clause)
      clause.result_ids(limit: query._limit, offset: query._offset)
    end

    def handle_result_set(result_set)
      start = query._offset || 0
      stop = query._limit.nil? ? -1 : start + query._limit
      redis.zrange(result_set, start, stop)
    end

    def postprocess_output(ids)
      Jobba::Statuses.new(ids)
    end
  end

  class CountStatuses < Operations
    def handle_single_clause(clause)
      clause.result_count(limit: query._limit, offset: query._offset)
    end

    def handle_result_set(result_set)
      redis.zcard(result_set)
    end

    def postprocess_output(nonlimited_count)
      Jobba::Utils.limited_count(nonlimited_count: nonlimited_count, offset: query._offset, limit: query._limit)
    end
  end

  def _run(operations)
    if _limit.nil? && !_offset.nil?
      raise ArgumentError, "`limit` must be set if `offset` is set", caller
    end

    load_default_clause if clauses.empty?

    if clauses.one?
      # We can make specialized calls that don't need intermediate copies of sets
      # to be made (which are costly)
      clause_output = operations.handle_single_clause(clauses.first)
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

      multi_result = redis.multi do

        working_set = nil

        clauses.each do |clause|
          clause_set = clause.to_new_set

          if working_set.nil?
            working_set = clause_set
          else
            redis.zinterstore(working_set, [working_set, clause_set], weights: [0, 0])
            redis.del(clause_set)
          end
        end

        # This is later accessed as `multi_result[-2]` since it is the second to last output
        operations.handle_result_set(working_set)

        redis.del(working_set)
      end

      clause_output = multi_result[-2]
    end

    operations.postprocess_output(clause_output)
  end

  def load_default_clause
    where(state: Jobba::State::ALL.collect(&:name))
  end

end
