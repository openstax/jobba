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
    attr_reader :multi_clause_block, :output_block, :single_clause_block

    def initialize(single_clause_block:, multi_clause_block:, output_block: nil)
      @single_clause_block = single_clause_block
      @multi_clause_block = multi_clause_block
      @output_block = output_block || ->(input) { input }
    end
  end

  GET_STATUSES = RunBlocks.new(
    single_clause_block: ->(clause) {
      clause.result_ids # becomes `clause.result_ids` and `output_block` used on this too
    },
    multi_clause_block: ->(working_set, redis) {
      redis.zrange(working_set, 0, -1)
    },
    output_block: ->(ids) {
      Jobba::Statuses.new(ids)
    }
  )

  COUNT_STATUSES = RunBlocks.new(
    single_clause_block: ->(clause) {
      clause.result_count
    },
    multi_clause_block: ->(working_set, redis) {
      redis.zcard(working_set)
    }
  )

  def _run(run_blocks)
    load_default_clause if clauses.empty?

    if clauses.one?
      # We can make specialized calls that don't need intermediate copies of sets
      # to be made (which are costly)
      clause_output = run_blocks.single_clause_block.call(clauses.first)
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
        run_blocks.multi_clause_block.call(working_set, redis)

        redis.del(working_set)
      end

      clause_output = multi_result[-2]
    end

    run_blocks.output_block.call(clause_output)
  end

  def load_default_clause
    where(state: Jobba::State::ALL.collect(&:name))
  end

end
