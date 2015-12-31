$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'byebug'

require 'spec_utils'
require 'fakeredis/rspec' if Jobba::Spec::Utils.use_fake_redis?
require 'helpers'

require 'jobba'

RSpec.configure do |config|

  config.include Helpers

  if Jobba::Spec::Utils.use_real_redis?
    config.before(:suite) do
      Jobba::Spec::Utils.clear_jobba_keys
    end

    config.after(:each) do
      Jobba::Spec::Utils.clear_jobba_keys
    end
  end

end


