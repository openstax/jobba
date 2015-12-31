class Jobba::Time

  # We can only accurately record times in redis up to microseconds.  Some
  # platforms, e.g. Mac OS, give Time up to microseconds while others, e.g.
  # Linux, give it up to nanoseconds.  To make our specs happy and to gel
  # with what redis is giving us, Jobba uses this Time class to enforce
  # rounding away precision beyond microseconds.

  def self.new(*args)
    Time.new(*args).round(6)
  end

  def self.now
    Time.new.round(6)
  end

  def self.at(*args)
    Time.at(*args).round(6)
  end

end
