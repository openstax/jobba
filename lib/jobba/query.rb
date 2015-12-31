require 'jobba/clause'
require 'jobba/clause_factory'

class Jobba::Query

  include Jobba::Common

  # def self.all
  #   new
  # end

  # TODO handle the OR wheres: "state: [:queued, :unqueued]"

  def where(options)
    options.each do |kk,vv|
      clauses.push(Jobba::ClauseFactory.new_clause(kk,vv))
    end

    self
  end

  # At the end of a chain of `where`s, the user will call methods that expect
  # to run on the result of the executed `where`s.  So if we don't know what
  # the method is, execute the `where`s and pass the method to its output.

  def method_missing(method_name, *args)
    if Jobba::Statuses.instance_methods.include?(method_name)
      run.send(method_name, *args)
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

  def run

    # TODO PUT IN MULTI BLOCKS WHERE WE CAN!
    # TODO implement where(state: [:queued, :working])

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

    ids = redis.zrange(working_set, 0, -1)
    redis.del(working_set)

    Jobba::Statuses.new(ids)
  end







  # Jobba.queued # those jobs that are currently queued
  # Jobba.queued(between: [t1, t2]) # those jobs that were queued between the times
  #   # is this queued_at(betweent: ...)?  or queued_between(t1,t2)
  # Jobba.queued(between: [t1, t2]).kill # kill all jobs queued in that time range
  # Jobba.queued(after: t1).completed(before: t2)
  # Jobba.job_named('job_name')
  # Jobba.job_named('job_name').failed
  # Jobba.failed.job_named('job_name')
  # Jobba.succeeded.duration.average
  # Jobba.succeeded(before: 1.week.ago).clear
  # Jobba.completed
  # Jobba.incomplete
  # Jobba.failed.time_descending
  # Jobba.for_arg(some_argument)  # job needs to note the status itself
  # Jobba.all
  # Jobba.job_names  # return all known job names

  # ----------

  # Jobba.where(state: :queued).where(job_name: 'blah')
  # Jobba.where(state: [:queued, :unqueued])

end
