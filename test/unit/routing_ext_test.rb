require 'minitest/autorun'
require 'active_support/all'
require 'rails/railtie'
require 'rails/version'

# rails/test_help wants a booted Rails.application before it will even
# load on current Rails, which this gem's own test_helper.rb can't give it
# yet. jsonapi_resources itself doesn't need a booted app, just a RouteSet,
# so this test builds the smallest environment that lets us draw routes
# with it directly.
module Rails
  def self.env
    ActiveSupport::StringInquirer.new('test')
  end
end

require 'action_controller'
require 'jsonapi-resources'

class ExampleResource < JSONAPI::Resource
end

class RoutingExtTest < Minitest::Test
  def test_jsonapi_resources_draws_routes
    route_set = ActionDispatch::Routing::RouteSet.new
    route_set.draw do
      jsonapi_resources :examples
    end

    paths = route_set.routes.map { |r| r.path.spec.to_s }
    assert_includes paths, '/examples(.:format)'
    assert_includes paths, '/examples/:id(.:format)'
  end
end
