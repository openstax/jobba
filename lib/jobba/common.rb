module Jobba::Common
  def redis
    Jobba.redis
  end

  def transaction(&block)
    Jobba.transaction(&block)
  end

  module ClassMethods
    def redis
      Jobba.redis
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
