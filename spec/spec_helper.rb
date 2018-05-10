$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'byebug'

require 'spec_utils'
require 'fakeredis/rspec' if Jobba::Spec::Utils.use_fake_redis?
require 'helpers'

require 'jobba'

RSpec.configure do |config|

  config.include Helpers

  if Jobba::Spec::Utils.use_real_redis?
    config.before(:each) do
      Jobba.clear_all_jobba_data!
    end

    config.after(:suite) do
      Jobba.clear_all_jobba_data!
    end
  end

end
