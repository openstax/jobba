# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jobba/version'

Gem::Specification.new do |spec|
  spec.name          = "jobba"
  spec.version       = Jobba::VERSION
  spec.authors       = ["JP Slavinsky"]
  spec.email         = ["jps@kindlinglabs.com"]

  spec.summary       = %q{Redis-based background job status tracking.}
  spec.description   = %q{Redis-based background job status tracking.}
  spec.homepage      = "https://github.com/openstax/jobba"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "redis"
  spec.add_runtime_dependency "oj"
  spec.add_runtime_dependency "redis-namespace"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "fakeredis"
end
