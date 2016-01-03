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
    run(&COUNT_STATUSES)
  end

  def empty?
    count == 0
  end

  # At the end of a chain of `where`s, the user will call methods that expect
  # to run on the result of the executed `where`s.  So if we don't know what
  # the method is, execute the `where`s and pass the method to its output.

  def method_missing(method_name, *args)
    if Jobba::Statuses.instance_methods.include?(method_name)
      run(&GET_STATUSES).send(method_name, *args)
    else
      super
    end
  end

  def respond_to?(method_name)
    Jobba::Statuses.instance_methods.include?(method_name) || super
  end

  protected

  attr_accessor :clauses

  def initialize
    @clauses = []
  end

  GET_STATUSES = ->(working_set) {
    ids = Jobba.redis.zrange(working_set, 0, -1)
    Jobba::Statuses.new(ids)
  }

  COUNT_STATUSES = ->(working_set) {
    Jobba.redis.zcard(working_set)
  }

  def run(&working_set_block)

    # TODO PUT IN MULTI BLOCKS WHERE WE CAN!

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

    working_set_block.call(working_set).tap do
      redis.del(working_set)
    end
  end

  def load_default_clause
    where(state: Jobba::State::ALL.collect(&:name))
  end

end
