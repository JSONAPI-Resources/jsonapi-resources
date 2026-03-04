begin
  require 'bundler/inline'
rescue LoadError => e
  STDERR.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true) do
  source 'https://rubygems.org'

  gem 'rails', require: false
  gem 'sqlite3', platform: :mri

  gem 'activerecord-jdbcsqlite3-adapter',
      git: 'https://github.com/jruby/activerecord-jdbc-adapter',
      platform: :jruby

  gem 'jsonapi-resources', require: false
end

# prepare active_record database
require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  # Add your schema here
  create_table :your_models, force: true do |t|
    t.string :name
  end
end

# create models
class YourModel < ActiveRecord::Base
end

# prepare rails app
require 'action_controller/railtie'
# require 'action_view/railtie'
require 'jsonapi-resources'

class ApplicationController < ActionController::Base
end

# prepare jsonapi resources and controllers
class YourModelsController < ApplicationController
  include JSONAPI::ActsAsResourceController
end

class YourModelResource < JSONAPI::Resource
  attribute :name
  filter :name
end

class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
  config.logger = Logger.new(STDOUT)
  Rails.logger = config.logger

  secrets.secret_token = 'secret_token'
  secrets.secret_key_base = 'secret_key_base'

  config.eager_load = false
end

# initialize app
Rails.application.initialize!

JSONAPI.configure do |config|
  config.json_key_format = :underscored_key
  config.route_format = :underscored_key
end

# draw routes
Rails.application.routes.draw do
  jsonapi_resources :your_models, only: [:index, :create]
end

# prepare tests
require 'minitest/autorun'
require 'rack/test'

# Replace this with the code necessary to make your test fail.
class BugTest < Minitest::Test
  include Rack::Test::Methods

  def json_api_headers
    {'Accept' => JSONAPI::MEDIA_TYPE, 'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE}
  end

  def test_index_your_models
    record = YourModel.create! name: 'John Doe'
    get '/your_models', nil, json_api_headers
    assert last_response.ok?
    json_response = JSON.parse(last_response.body)
    refute_nil json_response['data']
    refute_empty json_response['data']
    refute_empty json_response['data'].first
    assert record.id.to_s, json_response['data'].first['id']
    assert 'your_models', json_response['data'].first['type']
    assert({'name' => 'John Doe'}, json_response['data'].first['attributes'])
  end

  def test_create_your_models
    json_request = {
        'data' => {
            type: 'your_models',
            attributes: {
                name: 'Jane Doe'
            }
        }
    }
    post '/your_models', json_request.to_json, json_api_headers
    assert last_response.created?
    refute_nil YourModel.find_by(name: 'Jane Doe')
  end

  private

  def app
    Rails.application
  end
end
