source 'https://rubygems.org'

gemspec

gem 'pg'
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