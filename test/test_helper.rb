require 'simplecov'
require 'database_cleaner'

# To run tests with coverage:
# COVERAGE=true bundle exec rake test

# To test on a specific rails version use this:
# export RAILS_VERSION=5.2.4.4; bundle update; bundle exec rake test
# export RAILS_VERSION=6.0.3.4; bundle update; bundle exec rake test
# export RAILS_VERSION=6.1.1; bundle update; bundle exec rake test

# We are no longer having Travis test Rails 4.2.11., but you can try it with:
# export RAILS_VERSION=4.2.11; bundle update rails; bundle exec rake test

# To Switch rails versions and run a particular test order:
# export RAILS_VERSION=6.1.1; bundle update; bundle exec rake TESTOPTS="--seed=39333" test

if ENV['COVERAGE']
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/vendor/'

    add_group 'Controllers', 'lib/jsonapi/acts_as_resource_controller'
    add_group 'Resources', 'lib/jsonapi/resource'
    add_group 'Serializers', 'lib/jsonapi/serializer'
    add_group 'Processors', 'lib/jsonapi/processor'
    add_group 'ActiveRelation', 'lib/jsonapi/active_relation'
    add_group 'Routing', 'lib/jsonapi/routing'

    track_files 'lib/**/*.rb'

    # Enable branch coverage (requires Ruby 2.5+)
    enable_coverage :branch if respond_to?(:enable_coverage)

    # Formatting options
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::SimpleFormatter  # Console output
    ])
  end
end

ENV['DATABASE_URL'] ||= "sqlite3:test_db"

require 'active_record/railtie'

# Rails 7.1+ requires a different initialization order
if Rails::VERSION::MAJOR >= 8 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1)
  Rails.env = 'test'

  class TestApp < Rails::Application
    config.eager_load = false
    config.root = File.dirname(__FILE__)
    config.session_store :cookie_store, key: 'session'
    config.secret_key_base = 'secret'

    #Raise errors on unsupported parameters
    config.action_controller.action_on_unpermitted_parameters = :raise

    ActiveRecord::Schema.verbose = false
    # Rails 8.0+ removed :none as a valid schema_format option
    config.active_record.schema_format = Rails::VERSION::MAJOR >= 8 ? :ruby : :none
    config.active_support.test_order = :random

    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
    config.active_record.belongs_to_required_by_default = false
  end

  # Initialize before requiring rails/test_help for Rails 7.1+
  TestApp.initialize!
end

require 'rails/test_help'
require 'minitest/mock'
require 'jsonapi-resources'
require 'pry'

require File.expand_path('../helpers/value_matchers', __FILE__)
require File.expand_path('../helpers/assertions', __FILE__)
require File.expand_path('../helpers/functional_helpers', __FILE__)
require File.expand_path('../helpers/configuration_helpers', __FILE__)

Rails.env = 'test'

I18n.load_path += Dir[File.expand_path("../../locales/*.yml", __FILE__)]
I18n.enforce_available_locales = false

JSONAPI.configure do |config|
  config.json_key_format = :camelized_key
end

# Rails 7.2+ removed ActiveSupport::Deprecation.silenced= in favor of Rails.application.deprecators
if ActiveSupport::Deprecation.respond_to?(:silenced=)
  ActiveSupport::Deprecation.silenced = true
elsif defined?(Rails.application) && Rails.application.respond_to?(:deprecators)
  Rails.application.deprecators.silenced = true
end

puts "Testing With RAILS VERSION #{Rails.version}"

# For Rails < 7.1, define TestApp here (after rails/test_help)
unless Rails::VERSION::MAJOR >= 8 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1)
  class TestApp < Rails::Application
    config.eager_load = false
    config.root = File.dirname(__FILE__)
    config.session_store :cookie_store, key: 'session'
    config.secret_key_base = 'secret'

    #Raise errors on unsupported parameters
    config.action_controller.action_on_unpermitted_parameters = :raise

    ActiveRecord::Schema.verbose = false
    config.active_record.schema_format = :none
    config.active_support.test_order = :random

    config.active_support.halt_callback_chains_on_return_false = false
    config.active_record.time_zone_aware_types = [:time, :datetime]
    config.active_record.belongs_to_required_by_default = false
    if Rails::VERSION::MAJOR == 5 && Rails::VERSION::MINOR == 2
      config.active_record.sqlite3.represent_boolean_as_integer = true
    end
  end
end

DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner.strategy = :transaction

module MyEngine
  class Engine < ::Rails::Engine
    isolate_namespace MyEngine
  end
end

module ApiV2Engine
  class Engine < ::Rails::Engine
    isolate_namespace ApiV2Engine
  end
end

# Monkeypatch ActionController::TestCase to delete the RAW_POST_DATA on subsequent calls in the same test.
module ClearRawPostHeader
  def process(action, **args)
    @request.delete_header 'RAW_POST_DATA'
    super action, **args
  end
end

class ActionController::TestCase
  prepend ClearRawPostHeader
end

# Patch to allow :api_json mime type to be treated as JSON
# Otherwise it is run through `to_query` and empty arrays are dropped.
module ActionController
  class TestRequest < ActionDispatch::TestRequest
    def request_parameters=(params)
      if self.request_method == "GET"
        @env.delete('action_dispatch.request.request_parameters')
        self.query_string = params.to_query
      else
        super(params)
      end
    end

    alias_method :request_parameters=, :request_parameters=
  end
end

# Patch Rack 3.0+ to support old ActionDispatch::TestResponse methods
if Rack.release >= "3.0" && !ActionDispatch::TestResponse.method_defined?(:response_code)
  class ActionDispatch::TestResponse
    alias :response_code :status
  end
end

module JSONAPI
  class Request
    alias_method :_original_parse_fields, :parse_fields

    def parse_fields(fields)
      _original_parse_fields(fields) || {}
    end
  end
end

module AssertionHelpers
  def assert_no_missing_or_extra_fields(resource_klass, expected, actual, at_path: "")
    missing = []
    expected.each_pair { |k,v| missing << k unless actual.include?(k) }
    extra = []
    actual.each_pair { |k,v| extra << k unless expected.include?(k) }

    message = ""
    unless missing.empty?
      message += "Missing field(s) #{missing.join(", ")} for resource type #{resource_klass.name.underscore}"
      message += " at path #{at_path}" unless at_path.empty?
      message += "."
    end
    unless extra.empty?
      message += " " unless message.empty?
      message += "Extra field(s) #{extra.join(", ")} for resource type #{resource_klass.name.underscore}"
      message += " at path #{at_path}" unless at_path.empty?
      message += "."
    end
    assert(missing.empty?, message)
    assert(extra.empty?, message)
  end
end

def assert_query_count(expected)
  @queries = []
  callback = lambda do |_name, _started, _finished, _id, payload|
    unless payload[:name] =~ /SCHEMA|TRANSACTION|Prefetch/
      @queries << payload[:sql]
    end
  end
  result = nil
  ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
    result = yield
  end

  if @queries.size != expected
    puts "Queries (count: #{@queries.size}):"
    @queries.each_with_index do |query, index|
      puts "  #{index + 1}. #{query}"
    end
  end

  assert_equal expected, @queries.size, "Expected #{expected} queries, got #{@queries.size}"
  @queries = nil
  result
end

def count_queries(&block)
  @queries = []
  callback = lambda do |_name, _started, _finished, _id, payload|
    unless payload[:name] =~ /SCHEMA|TRANSACTION|Prefetch/
      @queries << payload[:sql]
    end
  end
  ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &block)

  show_queries
  @queries = nil
end

def show_queries
  @queries.each_with_index do |query, index|
    puts "sql[#{index}]: #{query}"
  end
end

# Initialize TestApp for Rails < 7.1 (for Rails 7.1+ it was already initialized)
unless Rails::VERSION::MAJOR >= 8 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1)
  TestApp.initialize!
end

require File.expand_path('../fixtures/active_record', __FILE__)

module Pets
  module V1
    class CatsController < JSONAPI::ResourceController
    end
  end
end

TestApp.routes.draw do
  namespace :api do
    namespace :v1 do
      jsonapi_resources :authors
      jsonapi_resources :people
      jsonapi_resources :comments
      jsonapi_resources :tags
      jsonapi_resources :posts do
        jsonapi_link :author, except: [:destroy]
        jsonapi_links :tags, only: [:show, :create, :update, :destroy]
      end
      jsonapi_resources :sections
      jsonapi_resources :iso_currencies
      jsonapi_resources :expense_entries
      jsonapi_resources :breeds
      jsonapi_resources :planets
      jsonapi_resources :planet_types
      jsonapi_resources :moons
      jsonapi_resources :preferences
      jsonapi_resources :facts
      jsonapi_resources :categories
      jsonapi_resources :pictures
      jsonapi_resources :documents

      namespace :library do
        jsonapi_resources :books
        jsonapi_resources :book_comments, only: [:index, :show]
      end
    end

    namespace :v2 do
      jsonapi_resources :authors, except: [:destroy] do
        jsonapi_link :author_detail
        jsonapi_related_resource :author_detail
      end

      jsonapi_resources :author_details

      jsonapi_resources :people, except: [:destroy, :create] do
      end

      jsonapi_resources :posts, only: [:index, :show] do
        jsonapi_link :author, except: [:destroy]
      end

      jsonapi_resources :books, only: [:index, :show]
      jsonapi_resources :book_comments, except: [:destroy]

      namespace :library do
        jsonapi_resources :books do
          jsonapi_related_resources :book_comments
          jsonapi_related_resources :authors
        end

        jsonapi_resources :book_comments
      end
    end

    namespace :v3 do
      jsonapi_resource :preferences, except: [:create]
    end

    namespace :v4 do
      jsonapi_resources :posts do
        jsonapi_link :author
        jsonapi_links :tags
      end
      jsonapi_resources :iso_currencies
      jsonapi_resources :expense_entries
      jsonapi_resources :books
    end

    namespace :v5 do
      jsonapi_resources :posts, except: [] do
        jsonapi_link :author
        jsonapi_related_resource :author
        jsonapi_links :tags
        jsonapi_related_resources :tags
      end

      jsonapi_resources :authors, except: []
      jsonapi_resources :tags, except: []
    end

    namespace :v6 do
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
    end

    namespace :v7 do
      jsonapi_resources :customers
      jsonapi_resources :purchase_orders
      jsonapi_resources :line_items
      jsonapi_resources :clients
      jsonapi_resources :suppliers
      jsonapi_resources :products
    end

    namespace :v8 do
      jsonapi_resources :numeros_telefone
    end

    namespace :v9 do
      jsonapi_resources :professionals
    end
  end

  namespace :my_engine, path: 'boomshaka' do
    jsonapi_resources :cars
  end

  scope '/api_v2_engine', module: 'api_v2_engine/api/v2' do
    jsonapi_resources :books
  end

  mount MyEngine::Engine => "/boomshaka", as: :my_engine
  mount ApiV2Engine::Engine => "/api_v2_engine", as: :api_v2_engine
end

MyEngine::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      jsonapi_resources :cars
    end
  end
end

ApiV2Engine::Engine.routes.draw do
  namespace :api do
    namespace :v2 do
      jsonapi_resources :books
    end
  end
end

class Minitest::Test
  include GeneratedRequests
  include Helpers::ValueMatchers
  include Helpers::Configuration
  include Helpers::Assertions
  include AssertionHelpers

  def setup
    $test_user_id = nil
    $test_user_name = nil
    $test_permission_sets = []
  end

  def run_in_transaction?
    true
  end

  # Rails 7.2+ changed fixture_path= to fixture_paths=
  if respond_to?(:fixture_paths=)
    self.fixture_paths = ["#{Rails.root}/fixtures"]
  else
    self.fixture_path = "#{Rails.root}/fixtures"
  end
  fixtures :all

  def json_response
    return nil if response.body.to_s.strip.empty?
    JSON.parse(response.body)
  end

  def assert_jsonapi_get(url, params = {}, headers = {})
    get url, params: params, headers: headers
    assert_jsonapi_response
  end

  def assert_cacheable_get(url, params = {})
    get url, params: params
    assert_cacheable_jsonapi_response
  end

  def assert_jsonapi_post(url, params = {})
    post url, params: params, as: :json
    assert_jsonapi_response
  end

  def assert_jsonapi_patch(url, params = {})
    patch url, params: params, as: :json
    assert_jsonapi_response
  end

  def assert_jsonapi_delete(url)
    delete url
    assert_response :success
  end

  def setup_request
    @request.headers['Accept'] = JSONAPI::MEDIA_TYPE
    @request.headers['Content-Type'] = JSONAPI::MEDIA_TYPE
  end

  def assert_jsonapi_response
    assert response.headers['Content-Type'].include?(JSONAPI::MEDIA_TYPE), "Invalid content type: #{response.headers['Content-Type']}"
  end

  def assert_cacheable_jsonapi_response
    assert_jsonapi_response
    assert_equal 'max-age=3600, private', response.headers['Cache-Control'], "Cache-Control header is missing or wrong: #{response.headers['Cache-Control']}"
  end

  def assert_cacheable_jsonapi_get(url, params = {}, headers = {})
    assert_jsonapi_get(url, params, headers)
    assert_cacheable_jsonapi_response
  end

  def assert_response_includes_query(query_data)
    cache_activity = gather_cache_activity do
      mode = query_data[:mode]
      warmup = query_data[:warmup_block]
      lookup = query_data[:lookup_block]

      assert_not_nil mode, "Mode must be specified"

      cache_activity = {
        warmup: { total: { misses: 0, hits: 0 } },
        lookup: { total: { misses: 0, hits: 0 } }
      }

      if warmup
        Rails.cache.clear
        cache_activity[:warmup] = gather_cache_activity(&warmup)
      end

      if lookup
        cache_activity[:lookup] = gather_cache_activity(&lookup)
      end

      if warmup
        if query_data[:no_response_data]
          assert_equal(
            0,
            cache_activity[:warmup][:total][:misses],
            "Cache (mode: #{mode}) warmup response with empty data must not cause any cache misses"
          )
        else
          assert_operator(
            cache_activity[:warmup][:total][:misses],
            :>,
            0,
            "Cache (mode: #{mode}) warmup response with non-empty data must cause cache misses"
          )
        end
      end

      if lookup
        assert_equal 0, cache_activity[:lookup][:total][:misses],
                     "Cache (mode: #{mode}) lookup response must not cause any cache misses"
        assert_operator(
          cache_activity[:lookup][:total][:hits],
          :>=,
          cache_activity[:warmup][:total][:misses],
         "Cache (mode: #{mode}) lookup response must use cache entries created by warmup"
        )
      end
    end

    @queries = orig_queries
  end

  private

  def json_response_sans_all_backtraces
    return nil if response.body.to_s.strip.empty?

    r = json_response.dup
    (r["errors"] || []).each do |err|
      err["meta"].delete("backtrace") if err.has_key?("meta")
      err["meta"].delete("application_backtrace") if err.has_key?("meta")
    end
    return r
  end
end

class IntegrationBenchmark < ActionDispatch::IntegrationTest
  def self.runnable_methods
    methods_matching(/^bench_/)
  end

  def self.run_one_method(klass, method_name, reporter)
    Benchmark.bmbm(method_name.length) do |job|
      job.report(method_name) do
        super(klass, method_name, reporter)
      end
    end
    puts
  end
end

class UpperCamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.camelize(:upper)
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DateWithTimezoneValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.in_time_zone('Eastern Time (US & Canada)').to_s
    end
  end
end

class DateValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      raw_value.strftime('%m/%d/%Y')
    end
  end
end

class TitleValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      super(raw_value).titlecase
    end

    def unformat(value)
      value.to_s.downcase
    end
  end
end

class OptionalRouteFormatter < JSONAPI::RouteFormatter
  class << self
    def format(route)
      return if route == 'v1'
      super
    end

    def unformat(formatted_route)
      super
    end
  end
end
