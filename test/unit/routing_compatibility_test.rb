require 'logger'
require 'minitest/autorun'
require 'active_support/all'
require 'rails'
require 'action_controller'
require 'jsonapi-resources'

class RoutingCompatibilityResource < JSONAPI::Resource
end

class RoutingProfileResource < JSONAPI::Resource
  singleton singleton_key: -> (context) { context[:current_user_id] }
end

class RoutingCompatibilityTest < Minitest::Test
  def test_plural_routes_preserve_keyword_options
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      jsonapi_resources :routing_compatibilities, controller: 'examples', only: [:index, :show]
    end

    path = JSONAPI.configuration.route_formatter.format('routing_compatibilities')
    assert_equal "/#{path}", routes.url_helpers.routing_compatibilities_path
    assert_equal "/#{path}/42", routes.url_helpers.routing_compatibility_path(42)
    assert_equal ['examples'], routes.routes.map { |route| route.defaults[:controller] }.uniq
    refute_includes routes.routes.map(&:verb), 'DELETE'
  end

  def test_singleton_routes_preserve_keyword_options
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      jsonapi_resource :routing_profile, controller: 'profiles', only: [:show]
    end

    assert_equal "/#{JSONAPI.configuration.route_formatter.format('routing_profile')}", routes.url_helpers.routing_profile_path
    assert_equal ['profiles'], routes.routes.map { |route| route.defaults[:controller] }.uniq
    refute_includes routes.routes.map(&:verb), 'DELETE'
  end
end
