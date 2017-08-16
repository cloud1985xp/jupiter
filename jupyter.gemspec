# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jupyter/version'

Gem::Specification.new do |spec|
  spec.name          = "jupyter"
  spec.version       = Jupyter::VERSION
  spec.authors       = ["Aaron Kuo"]
  spec.email         = ["atk.cloud1985xp@gmail.com"]

  spec.summary       = %q{A simple wrapper to develop stress testing with ruby-jmeter}
  spec.description   = %q{A simple wrapper to develop stress testing with ruby-jmeter}
  spec.homepage      = "https://github.com/cloud1985xp/jupyter"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport", "~> 5.0.2"
  spec.add_runtime_dependency "ruby-jmeter", "~> 3.1.05"
  spec.add_runtime_dependency "aws-sdk", "~> 2"
  spec.add_runtime_dependency "text-table", "1.2.3"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
