# jobba

Redis-based background job status tracking.

## Configuration

To configure Lev, put the following code in your applications
initialization logic (eg. in the config/initializers in a Rails app)

```ruby
Jobba.configure do |config|
  # Whatever options should be passed to `Redis.new` (see https://github.com/redis/redis-rb)
  config.redis_options = {url: "redis://:p4ssw0rd@10.0.1.1:6380/15"}
  # top-level redis prefix
  config.namespace = "jobba"
end
```
