# jobba

[![Build Status](https://travis-ci.org/openstax/jobba.svg?branch=master)](https://travis-ci.org/openstax/jobba)
[![Code Climate](https://codeclimate.com/github/openstax/jobba/badges/gpa.svg)](https://codeclimate.com/github/openstax/jobba)

Redis-based background job status tracking.

## Configuration

To configure Jobba, put the following code in your applications
initialization logic (eg. in the config/initializers in a Rails app):

```ruby
Jobba.configure do |config|
  # Whatever options should be passed to `Redis.new` (see https://github.com/redis/redis-rb)
  config.redis_options = { url: "redis://:p4ssw0rd@10.0.1.1:6380/15" }
  # top-level redis prefix
  config.namespace = "jobba"
end
```

## TODO

1. Clearing jobs should get rid of all traces.
2. Need to track job names and important arguments.
3. add_error
4. enforce order progression of states (no skipping) -- actually just note in readme that order is not enforced, clients can call what they want when, just need to be aware that timestamps won't be set or states entered automatically for them.
5. Note in readme that Time objects expected or (floats that are seconds since epoch) or integers that are usecs since epoch or strings that are usecs since epoch
  * even if OS supports ns time, this gem ignores nanoseconds
6. clause and clause factory specs
7. Note in readme: "kill requested" isn't really a state but rather a condition -- while kill is requested the job is still in some other state (eg still "working"). only when it is actually killed does it change states (to "killed")
8. Specs that test scale
9. Sprinkle multi around
10. Add a convenience `where(state: :complete)` and `where(state: :incomplete)`??




```ruby
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
```
