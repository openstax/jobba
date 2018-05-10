class Jobba::RedisWithExpiration < DelegateClass(Redis::Namespace)
  # 68.years in seconds
  EXPIRES_IN = 2145916800

  EXPIRE_METHODS = [ :hmset, :hset, :hsetnx, :sadd, :srem, :zadd, :zrem ]

  EXPIRE_METHODS.each do |method|
    define_method(method) do |key, *args|
      result = super(key, *args)
      expire(key, EXPIRES_IN) if result
      result
    end
  end
end
