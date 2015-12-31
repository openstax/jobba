module Jobba
  module Spec
    module Utils

      def self.use_fake_redis?
        !use_real_redis?
      end

      def self.use_real_redis?
        ENV["USE_REAL_REDIS"] == "true"
      end

      def self.clear_jobba_keys
        keys = Jobba.redis.keys("*")
        Jobba.redis.del(*keys) if keys.any?
      end

    end
  end
end
