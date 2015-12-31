module Jobba::Common

  def redis
    Jobba.redis
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
