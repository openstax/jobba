# jobba

[![Build Status](https://travis-ci.org/openstax/jobba.svg?branch=master)](https://travis-ci.org/openstax/jobba)
[![Code Climate](https://codeclimate.com/github/openstax/jobba/badges/gpa.svg)](https://codeclimate.com/github/openstax/jobba)

Redis-based background job status tracking.

## Installation

```ruby
# Gemfile
gem 'jobba'
```

or

```
$> gem install jobba
```

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

## Getting status objects

If you know you need a new `Status`, call `create!`:

```ruby
Jobba::Status.create!
```

If you are looking for a status:

```ruby
Jobba::Status.find(id)
```

which will return `nil` if no such `Status` is found. If you always want a `Status` object back,
call:

```ruby
Jobba::Status.find!(id)
```

The results of `find!` will always start in an `unknown` state.

## Basic Use with ActiveJob

```ruby
class MyJob < ::ActiveJob::Base
  def self.perform_later(an_arg:, another_arg:)
    status = Jobba::Status.create!
    args.push(status.id)

    # In theory we'd mark as queued right after the call to super, but this messes
    # up when the activejob adapter runs the job right away
    status.queued!
    super(*args, &block)

    # return the Status ID in case it needs to be noted elsewhere
    status.id
  end

  def perform(*args, &block)
    # Pop the ID argument added by perform_later and get a Status
    status = Jobba::Status.find!(args.pop)
    status.working!

    # ... do stuff ...

    status.succeeded!
  end
end
```

## Change States

* talk about timestamps & precision
* note that order is not enforced, clients can call what they want when, just need to be aware that timestamps won't be set or states entered automatically for them.

## Mark Progress

## Recording Job Errors

## Saving Job-specific Data

## Setting Job Name and Arguments

## Killing Jobs

TBD: "kill requested" isn't really a state but rather a condition -- while kill is requested the job is still in some other state (eg still "working"). only when it is actually killed does it change states (to "killed")

## Status Attributes

## Deleting Job Statuses

## Querying for Statuses

Jobba has an activerecord-like query interface for finding Status objects.

### Basic Query Examples

**State**

```ruby
Jobba.where(state: :unqueued)
Jobba.where(state: :queued)
Jobba.where(state: :working)
Jobba.where(state: :succeeded)
Jobba.where(state: :failed)
Jobba.where(state: :killed)
Jobba.where(state: :unknown)
```

You can query combinations of states too:

```ruby
Jobba.where(state: [:queued, :working])
```

**State Timestamp**

```ruby
Jobba.where(recorded_at: {after: time_1})
Jobba.where(queued_at: [time_1, nil])
Jobba.where(started_at: {before: time_2})
Jobba.where(started_at: [nil, time_2])
Jobba.where(succeeded_at: {after: time_1, before: time_2})
Jobba.where(failed_at: [time_1, time_2])
```

**Job Name**

(requires having called the optional `set_job_name` method)

```ruby
Jobba.where(job_name: "MySpecialBackgroundJob")
Jobba.where(job_name: ["MySpecialBackgroundJob", "MyOtherJob"])
```

**Job Arguments**

(requires having called the optional `add_job_arg` method)

```ruby
Jobba.where(job_arg: "gid://app/MyModel/42")
Jobba.where(job_arg: "gid://app/Person/86")
```

### Query Chaining

Queries can be chained! (intersects the results of each `where` clause)

```ruby
Jobba.where(state: :queued).where(recorded_at: {after: some_time})
Jobba.where(job_name: "MyTroublesomeJob").where(state: :failed)
```

### Operations on Queries

When you have a query you can run the following methods on it:

* ...
* ...

You can also call two special methods directly on `Jobba`:

```ruby
Jobba.all     # returns all statuses
Jobba.count   # returns count of all statuses
```

## Notes

### Times

Note in readme that Time objects expected or (floats that are seconds since epoch) or integers that are usecs since epoch or strings that are usecs since epoch
  * even if OS supports ns time, this gem ignores nanoseconds

## TODO

1. Provide job min, max, and average durations.
2. Implement `add_error`.
8. Specs that test scale.
9. Make sure we're calling `multi` or `pipelined` everywhere we can.
10. Add convenience `where(state: :complete)` and `where(state: :incomplete)` queries.





