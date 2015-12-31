module Helpers

  # A helper method for making Status objects with more control than is normally
  # available, to help with debugging specs
  def make_status(options)
    id = options[:id]
    state = options[:state]

    status =
      if id.nil?
        Jobba::Status.create!
      else
        # backdoor into creating a Status with a given ID to make test debugging easier

        raise "Cannot make a status with a specified ID if that ID already exists" \
          if Jobba::Status.find(id.to_s)

        Jobba::Status.find!(id.to_s)
      end

    # Whether or not all states are used is up to the code using this library;
    # for these specs, we assume that states are traversed in order.
    case state
    when :working
      status.queued!.working!
    when :succeeded
      status.queued!.working!.succeeded!
    when :failed
      status.queued!.working!.failed!
    else
      status.send("#{state}!") unless state.nil?
    end

    status
  end

end
