# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chalk-log/version'

Gem::Specification.new do |gem|
  gem.name          = 'chalk-log'
  gem.version       = Chalk::Log::VERSION
  gem.authors       = ['Greg Brockman', 'Andreas Fuchs', 'Andy Brody', 'Anurag Goel', 'Evan Broder', 'Nelson Elhage']
  gem.email         = ['gdb@gregbrockman.com', 'asf@boinkor.net', 'andy@stripe.com', '_@anur.ag', 'evan@stripe.com', 'nelhage@nelhage.com']
  gem.description   = %q{Extends classes with a `log` method}
  gem.summary       = %q{Chalk::Log makes any class loggable. It provides a logger that can be used for both structured and unstructured log.}
  gem.homepage      = 'https://github.com/stripe/chalk-log'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
  gem.add_dependency 'chalk-config'
  gem.add_dependency 'logging'
  gem.add_dependency 'lspace'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest', '~> 3.2.0'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'chalk-rake'
end
