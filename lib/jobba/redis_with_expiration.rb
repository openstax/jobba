# This class provides Redis commands that automatically set key expiration.
# The only commands modified are commands that:
# 1. Take their (only) key as the first argument
# AND
# 2. Modify said key
# AND
# 3. Don't already set the key expiration by themselves
class Jobba::RedisWithExpiration < SimpleDelegator
  # 68.years in seconds
  EXPIRES_IN = 2145916800

  EXPIRE_METHODS = [
    :append,
    :decr,
    :decrby,
    :hdel,
    :hincrby,
    :hincrbyfloat,
    :hmset,
    :hset,
    :hsetnx,
    :incr,
    :incrby,
    :incrbyfloat,
    :linsert,
    :lpop,
    :lpush,
    :lpushx,
    :lrem,
    :lset,
    :ltrim,
    :mapped_hmset,
    :migrate,
    :move,
    :pfadd,
    :pfmerge,
    :restore,
    :rpop,
    :rpush,
    :rpushx,
    :sadd,
    :set,
    :setbit,
    :setnx,
    :setrange,
    :sinterstore,
    :smove,
    :spop,
    :srem,
    :sunionstore,
    :zadd,
    :zincrby,
    :zinterstore,
    :zrem,
    :zremrangebyrank,
    :zremrangebyscore,
    :zunionstore
  ]

  EXPIRE_METHODS.each do |method|
    define_method method do |key, *args|
      result = super key, *args
      # Only set expiration if the command (seems to have) succeeded
      expire key, EXPIRES_IN if result
      result
    end
  end
end
