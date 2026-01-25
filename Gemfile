# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'bundler'
gem 'database_cleaner'
gem 'minitest'
gem 'minitest-spec-rails'
gem 'pg'
gem 'pry'
gem 'rake'
gem 'rubocop'
gem 'rubocop-minitest'
gem 'simplecov'
gem 'sqlite3', '>= 2.1'

version = ENV['RAILS_VERSION'] || 'default'

case version
when 'master'
  gem 'railties', { git: 'https://github.com/rails/rails.git' }
when 'default'
  gem 'railties', '>= 8.0'
else
  gem 'railties', "~> #{version}"
end
