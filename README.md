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

One of the main functions of Jobba is to let a job advance its status through a series of states:

* `unqueued`
* `queued`
* `working`
* `succeeded`
* `failed`
* `killed`
* `unknown`

Put a `Status` into one of these states by calling `that_state!`, e.g.

```ruby
my_state.working!
```

The `unqueued` state is entered when a `Status` is first created.  The `unknown` state is entered when `find!(id)` is called but the `id` is not known.  You can re-enter these states with the `!` methods, but note that the `recorded_at` timestamp will not be updated.

The **first time a state is entered**, a timestamp is recorded for that state.  Not all timestamp names match the state names:

| State | Timestamp |
|-------|-----------|
|unqueued  | recorded_at |
|queued    | queued_at   |
|working   | started_at  |
|succeeded | succeeded_at |
|failed    | failed_at    |
|killed    | killed_at    |
|unknown   | recorded_at  |

There is also a special timestamp for when a kill is requested, `kill_requested_at`.  More about this later.

The order of states is not enforced, and you do not have to use all states.  However, note that you'll only be able to query for states you use (Jobba doesn't automatically travel through states you skip) and if you're using an unusual order your time-based queries will have to reflect that order.

## Mark Progress

If you want to have a way to track the progress of a job, you can call:

```ruby
my_status.set_progress(0.7)   # 70% complete
my_status.set_progress(7,10)  # 70% complete
my_status.set_progress(14,20) # 70% complete
```

This is useful if you need to show a progress bar on your client, for example.

## Recording Job Errors

...

## Saving Job-specific Data

Jobba provides a `data` field in all `Status` objects that you can use for storing job-specific data.  Note that the data must be in a format that can be serialized to JSON.  Recommend sticking with basic data types, arrays, primitives, hashes, etc.

```ruby
my_status.save({a: 'blah', b: [1,2,3]})
my_status.save("some string")
```

## Setting Job Name and Arguments

If you want to be able to query for all statuses for a certain kind of job, you can set the job's name in the status:

```ruby
my_status.set_job_name("MySpecialJob")
```

If you want to be able to query for all statuses that take a certain argument as input, you can add job arguments to a status:

```ruby
my_status.add_job_arg(arg_name, arg)
```

where `arg_name` is what the argument is called in your job (e.g. `"input_1"`) and `arg` is a way to identify the argument (e.g. `"gid://app/Person/72").

You probably will only want to track complex arguments, e.g. models in your application.  E.g. you could have a `Book` model and a `PublishBook` background job and you may want to see all of the `PublishBook` jobs that have status for the `Book` with ID `53`.

## Killing Jobs

While Jobba can't really kill jobs (it doesn't control your job-running library), it has a facility for marking that you'd like a job to be killed.

```ruby
a_status.request_kill!
```

Then a job itself can occassionally come up for air and check

```ruby
my_status.kill_requested?
```

and if that returns `true`, it can attempt to gracefully terminate itself.

Note that when a kill is requested, the job will continue to be in some other state (e.g. `working`) until it is in fact killed, at which point the job should call:

```ruby
my_status.killed!
```

to change the state to `killed`.

## Status Objects

When you get hold of a `Status`, via `create!`, `find`, `find!`, or as the result of a query, it will have the following attributes (some of which may be nil):

| Attribute | Description |
|-----------|-------------|
| `id` | A Jobba-created UUID |
| `state` | one of the states above |
| `progress` | a float between 0.0 and 1.0 |
| `errors` | TBD |
| `data` | job-specific data |
| `job_name` | The name of the job |
| `job_args` | An hash of job arguments, {arg_name: arg, ...} |
| `recorded_at` | Ruby `Time` timestamp |
| `queued_at` | Ruby `Time` timestamp |
| `started_at` | Ruby `Time` timestamp |
| `succeeded_at` | Ruby `Time` timestamp |
| `failed_at` | Ruby `Time` timestamp |
| `killed_at` | Ruby `Time` timestamp |
| `recorded_at` | Ruby `Time` timestamp |
| `kill_requested_at` | Ruby `Time` timestamp |

A `Status` object also methods to check if it is in certain states:

* `reload!`
* `unqueued?`
* `queued?`
* `working?`
* `succeeded?`
* `failed?`
* `killed?`
* `unknown?`

And two conveience methods for checking groups of states:

* `completed?`
* `incomplete?`

You can also call `reload!` on a `Status` to have it reset its state to what is stored in redis.

## Deleting Job Statuses

Once jobs are completed or otherwise no longer interesting, it'd be nice to clear them out of redis.  You can do this with:

```ruby
my_status.delete    # freaks out if `my_status` isn't complete
my_status.delete!   # always deletes
```

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

Two convenience "state" queries have been added:

```ruby
Jobba.where(state: :completed)   # includes succeeded, failed
Jobba.where(state: :incomplete)  # includes unqueued, queued, working, killed
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

Note that you cannot query on `kill_requested_at`.  The time arguments can be Ruby `Time` objects or a number of microseconds since the epoch represented as a float, integer, or string.

Note that, in operations having to do with time, this gem ignores anything beyond microseconds.

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

When you have a query you can run the following methods on it.  These act like what you'd expect for a Ruby array.

* `first`
* `any?`
* `none?`
* `all?`
* `each`
* `each_with_index`
* `map`
* `collect`
* `select`
* `empty?`
* `count`

`empty?` and `count` are performed in redis without bringing back all query results to Ruby.

You can also call two special methods directly on `Jobba`:

```ruby
Jobba.all     # returns all statuses
Jobba.count   # returns count of all statuses
```

## Statuses Object

Calling `all` on a query returns a `Statuses` object, which is just a collection of `Status` objects.  It has a few methods for doing bulk operations on all `Status` objects in it.

* `delete`
* `delete!`
* `request_kill!`

These work like describe above for individual `Status` objects.

There is also a not-very-tested `multi` operation that takes a block and executes the block inside a Redis `multi` call.

```ruby
my_statuses.multi do |status, redis|
  # do stuff on `status` using the `redis` connection
end
```

## Notes

### Times

Note that, in operations having to do with time, this gem ignores anything beyond microseconds.

### Efficiency

Jobba strives to do all of its operations as efficiently as possible using built-in redis operations.  If you find a place where the efficiency can be improved, please submit an issue or a pull request.

## TODO

1. Provide job min, max, and average durations.
2. Implement `add_error`.
8. Specs that test scale.
9. Make sure we're calling `multi` or `pipelined` everywhere we can.
11. Make sure we're consistent on completed/complete incompleted/incomplete.
12. Should more `Statuses` operations return `Statuses`, e.g. `each`, so that they can be chained?





