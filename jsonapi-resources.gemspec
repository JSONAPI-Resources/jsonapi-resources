# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi/resources/version'

Gem::Specification.new do |spec|
  spec.name          = 'jsonapi-resources'
  spec.version       = JSONAPI::Resources::VERSION
  spec.authors       = ['Dan Gebhardt', 'Larry Gebhardt']
  spec.email         = ['dan@cerebris.com', 'larry@cerebris.com']
  spec.summary       = 'Easily support JSON API in Rails.'
  spec.description   = 'A resource-centric approach to implementing the controllers, routes, and serializers needed to support the JSON API spec.'
  spec.homepage      = 'https://github.com/cerebris/jsonapi-resources'
  spec.license       = 'MIT'

  spec.files         = Dir.glob("{bin,lib}/**/*") + %w(LICENSE.txt README.md)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.3'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest', '~> 5.10', '!= 5.10.2'
  spec.add_development_dependency 'minitest-spec-rails'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'concurrent-ruby-ext'
  spec.add_development_dependency 'database_cleaner'
  spec.add_dependency 'activerecord', '>= 5.1'
  spec.add_dependency 'railties', '>= 5.1'
  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'csv' # Required for Ruby 3.4+ (no longer a default gem)
end
