module Jobba
  module Spec
    module Utils

      def self.use_fake_redis?
        !use_real_redis?
      end

      def self.use_real_redis?
        ENV["USE_REAL_REDIS"] == "true"
      end

    end
  end
end
