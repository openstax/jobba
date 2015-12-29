class Jobba::State

  attr_reader :name, :timestamp_name

  def initialize(name, timestamp_name)
    @name = name
    @timestamp_name = timestamp_name
  end

  def self.from_name(state_name)
    ALL.select{|state| state.name == state_name}.first
  end

  UNQUEUED        = new('unqueued', 'recorded_at')
  QUEUED          = new('queued', 'queued_at')
  WORKING         = new('working', 'started_at')
  SUCCEEDED       = new('succeeded', 'succeeded_at')
  FAILED          = new('failed', 'failed_at')
  KILLED          = new('killed', 'killed_at')
  UNKNOWN         = new('unknown', 'recorded_at')

  ALL = [
    UNQUEUED,
    QUEUED,
    WORKING,
    SUCCEEDED,
    FAILED,
    KILLED,
    UNKNOWN
  ].freeze

end





