require 'jobba/clause'
require 'jobba/id_clause'
require 'jobba/clause_factory'

class Jobba::Query

  include Jobba::Common

  def where(options)
    options.each do |kk,vv|
      clauses.push(Jobba::ClauseFactory.new_clause(kk,vv))
    end

    self
  end

  def count
    _run(COUNT_STATUSES)
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
    _run(GET_STATUSES)
  end

  protected

  attr_accessor :clauses

  def initialize
    @clauses = []
  end

  class RunBlocks
    attr_reader :redis_block, :output_block

    def initialize(redis_block, output_block)
      @redis_block = redis_block
      @output_block = output_block
    end

    def output_block_result_is_redis_block_result?
      output_block.nil?
    end
  end

  GET_STATUSES = RunBlocks.new(
    ->(working_set, redis) {
      redis.zrange(working_set, 0, -1)
    },
    ->(ids) {
      Jobba::Statuses.new(ids)
    }
  )

  COUNT_STATUSES = RunBlocks.new(
    ->(working_set, redis) {
      redis.zcard(working_set)
    },
    nil
  )

  def _run(run_blocks)
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

    multi_result = redis.multi do
      load_default_clause if clauses.empty?
      working_set = nil

      clauses.each_with_index do |clause, ii|
        clause_set = clause.to_new_set

        if working_set.nil?
          working_set = clause_set
        else
          redis.zinterstore(working_set, [working_set, clause_set], weights: [0, 0])
          redis.del(clause_set)
        end
      end

      # This is later accessed as `multi_result[-2]` since it is the second to last output
      run_blocks.redis_block.call(working_set, redis)

      redis.del(working_set)
    end

    redis_block_output = multi_result[-2]

    run_blocks.output_block_result_is_redis_block_result? ?
      redis_block_output :
      run_blocks.output_block.call(redis_block_output)
  end

  def load_default_clause
    where(state: Jobba::State::ALL.collect(&:name))
  end

end
