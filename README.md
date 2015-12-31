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
4. enforce order progression of states (no skipping)
5. Note in readme that Time objects expected or (floats that are seconds since epoch) or integers that are usecs since epoch or strings that are usecs since epoch
