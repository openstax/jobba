# jobba

[![Gem Version](https://badge.fury.io/rb/jobba.svg)](http://badge.fury.io/rb/jobba)
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

Version 1.x.x follows the scheme, 1.major_change.minor_change.  Normal semantic versioning (major/minor/patch) will begin with version `2.0.0`.

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

The result of `find!` will start in an `unknown` state if the ID doesn't exist in Redis.

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
    status.started!

    # ... do stuff ...

    status.succeeded!
  end
end
```

## Change States

One of the main functions of Jobba is to let a job advance its status through a series of states:

* `unqueued`
* `queued`
* `started`
* `succeeded`
* `failed`
* `killed`
* `unknown`

Put a `Status` into one of these states by calling `that_state!`, e.g.

```ruby
my_state.started!
```

The `unqueued` state is entered when a `Status` is first created.  The `unknown` state is entered when `find!(id)` is called but the `id` is not known.  You can re-enter these states with the `!` methods, but note that the `recorded_at` timestamp will not be updated.

The **first time a state is entered**, a timestamp is recorded for that state.  Not all timestamp names match the state names:

| State | Timestamp |
|-------|-----------|
|unqueued  | recorded_at |
|queued    | queued_at   |
|started   | started_at  |
|succeeded | succeeded_at |
|failed    | failed_at    |
|killed    | killed_at    |
|unknown   | recorded_at  |

There is also a special timestamp for when a kill is requested, `kill_requested_at`.  More about this later.

The order of states is not enforced, and you do not have to use all states.  However, note that you'll only be able to query for states you use (Jobba doesn't automatically travel through states you skip) and if you're using an unusual order your time-based queries will have to reflect that order.

### Restarts

Generally-speaking, you should only enter any state once.  Jobba only records the timestamp the first time you enter a state.

The expection to this rule is that if call `started!` a second time, Jobba will note this as a restart.  The current values in the status will be archived and your status will look like a `started` status, with the exception that the `attempt` count will be incremented.  A restarted status can then enter `succeeded`, `failed`, or `killed` states and those timestamps will be stored.  `job_name` and `job_args` survive the restart.

The `attempt` field is zero-indexed, so the first attempt is attempt `0`.

## Mark Progress

If you want to have a way to track the progress of a job, you can call:

```ruby
my_status.set_progress(0.7)   # 70% complete
my_status.set_progress(7,10)  # 70% complete
my_status.set_progress(14,20) # 70% complete
```

This is useful if you need to show a progress bar on your client, for example.

## Recording Job Errors

The status can keep track of a list of errors.  Errors can be anything, as long as they are JSON-friendly.

```ruby
my_status.add_error("oh nooo!!")
my_status.add_error(msg: "oh nooo!!", data: 42)
```

Errors are available from an `errors` attribute

```ruby
my_status.errors # => ["oh nooo!!", {"msg" => "oh nooo!!", "data" => 42}]
```

## Saving Job-specific Data

Jobba provides a `data` field in all `Status` objects that you can use for storing job-specific data.  Note that the data must be in a format that can be serialized to JSON.  Recommend sticking with basic data types, arrays, primitives, hashes, etc.

```ruby
my_status.save({a: 'blah', b: [1,2,3]})
my_status.save("some string")
```

## Normalization of Saved Data and Errors

Note that if you `save` or `add_error` contains a hash with symbol keys, those keys will be converted to strings.  In fact, any argument passed in to these methods will be converted to JSON and parsed back again so that the `data` and `errors` attributes returns the same thing regardless of if they are retrieved immediately after being set or after being loaded from Redis.

## Setting Job Name and Arguments

If you want to be able to query for all statuses for a certain kind of job, you can set the job's name in the status:

```ruby
my_status.set_job_name("MySpecialJob")
```

If you want to be able to query for all statuses that take a certain argument as input, you can set job arguments on a status:

```ruby
my_status.set_job_args(arg_1_name: arg_2, arg_2_name: arg_2)
```

where the keys are what the argument is called in your job (e.g. `"input_1"`) and the values are a way to identify the argument (e.g. `"gid://app/Person/72"`).  The values must currently be strings.

You probably will only want to track complex arguments, e.g. models in your application.  E.g. you could have a `Book` model and a `PublishBook` background job and you may want to see all of the `PublishBook` jobs that have status for the `Book` with ID `53`.

Note that you can set job args with names that are either symbols or strings, but you can only read the args back by the string form of their name, e.g.

```ruby
my_status.set_job_args(foo: "bar")
my_status.job_args['foo']          # => "bar"
my_status.job_args[:foo]           # => nil
```

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

Note that when a kill is requested, the job will continue to be in some other state (e.g. `started`) until it is in fact killed, at which point the job should call:

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
| `errors` | an array of errors |
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
* `started?`
* `succeeded?`
* `failed?`
* `killed?`
* `unknown?`

And two conveience methods for checking groups of states:

* `completed?`
* `incomplete?`

You can also call `reload!` on a `Status` to have it reset its state to what is stored in Redis.

## Deleting Job Statuses

Once jobs are completed or otherwise no longer interesting, it'd be nice to clear them out of Redis.  You can do this with:

```ruby
my_status.delete    # freaks out if `my_status` isn't completed
my_status.delete!   # always deletes
```

## Querying for Statuses

Jobba has an activerecord-like query interface for finding Status objects.

### Basic Query Examples

**Getting All Statuses**

```ruby
Jobba.all
```

**State**

```ruby
Jobba.where(state: :unqueued)
Jobba.where(state: :queued)
Jobba.where(state: :started)
Jobba.where(state: :succeeded)
Jobba.where(state: :failed)
Jobba.where(state: :killed)
Jobba.where(state: :unknown)
```

Two convenience "state" queries have been added:

```ruby
Jobba.where(state: :completed)   # includes succeeded, failed
Jobba.where(state: :incomplete)  # includes unqueued, queued, started, killed
```

You can query combinations of states too:

```ruby
Jobba.where(state: [:queued, :started])
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

**Status IDs**

```ruby
Jobba.where(id: nil)
Jobba.where(id: [])
Jobba.where(id: "some_id")
Jobba.where(id: ["an_id", "another_id"])
```

### Query Chaining

Queries can be chained! (intersects the results of each `where` clause)

```ruby
Jobba.where(state: :queued).where(recorded_at: {after: some_time})
Jobba.where(job_name: "MyTroublesomeJob").where(state: :failed)
```

### Sort Order

Currently, results from queries are not guaranteed to be in any order.  You can sort them yourself using normal Ruby calls.

### Running a Query to get Statuses

```ruby
Jobba.where(...).run
```

When you call `run` on a query, you'll get back a `Statuses` object, which is simply a collection of `Status` objects with a few convenience methods and bulk operations.

**Bulk Methods on Statuses**

* `delete_all`
* `delete_all!`
* `request_kill_all!`

These work like describe above for individual `Status` objects.

There is also a not-very-tested `multi` operation that takes a block and executes the block inside a Redis `multi` call.  Do not use it unless you really know what you are doing.

```ruby
my_statuses.multi do |status, redis|
  # do stuff on `status` using the `redis` connection
end
```

**Array-like Methods on Statuses**

* `any?`
* `none?`
* `all?`
* `map`
* `collect`
* `empty?`
* `count`
* `select!`
* `reject!`

If you want to get an array of `Status` objects from a `Statuses` object, just call

```ruby
a_statuses_object.to_a
```

`select!` and `reject!`, as you would expect, operate in place and also return `self`.

### Passthrough Methods on Queries

As a convenience, if you call a method on `Query` that isn't defined there but is defined on `Statuses`, a new `Statuses` object will be created for you and your method called on it.

```ruby
Jobba.where(state: :queued).collect(&:queued_at)
```

is the same as

```ruby
Jobba.where(state: :queued).run.collect(&:queued_at)
```

### Query Counts

Notably, both `Query` and `Statuses` define the `count` and `empty?` methods.  Which ones you use affects if the counting is done in Redis or in Ruby:

```ruby
Jobba.where(...).count       # These count in Redis
Jobba.where(...).empty?
Jobba.all.count

Jobba.where(...).run.count   # These pull data back to Ruby and count in Ruby
Jobba.where(...).run.empty?
```

## Notes

### Times

Note that, in operations having to do with time, this gem ignores anything beyond microseconds.

### Efficiency

Jobba strives to do all of its operations as efficiently as possible using built-in Redis operations.  If you find a place where the efficiency can be improved, please submit an issue or a pull request.

### Write from one; Read from many

Jobba assumes that any job is being run at one time by only one worker.  Jobba makes no accomodations for multiple processes updating a Status at the same time; multiple processes reading of a Status are fine of course.

## Development

By default, this gem uses `fakeredis` instead of real Redis.  This is great most of the time, but occassionally `fakeredis` doesn't work exactly like real Redis.  If you want to use real Redis, just set the `USE_REAL_REDIS` environment variable to `true`, e.g.

```
$> USE_REAL_REDIS=true rspec
```

Travis runs the specs with both `fakeredis` and real Redis.

## TODO

1. Provide job min, max, and average durations.
8. Specs that test scale.
9. Move redis code in `set_job_args`, `set_job_name`, and `save` into `set` to match rest of code.





