require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'
require 'json'

module Api
  module Secret
    class PostResource < JSONAPI::Resource
      attribute :title
      attribute :body

      has_one :author, class_name: 'Person'
    end

    class PersonResource < JSONAPI::Resource
    end
  end
end

class LinkBuilderTest < ActionDispatch::IntegrationTest
  def setup
    # the route format is being set directly in test_helper and is being set differently depending on
    # the order in which the namespaces get loaded. in order to prevent random test seeds to fail we need to set the
    # default configuration in the test 'setup'.
    JSONAPI.configuration.route_format = :underscored_route

    @base_url        = "http://example.com"
    @route_formatter = JSONAPI.configuration.route_formatter
    @steve           = Person.create(name: "Steve Rogers", date_joined: "1941-03-01", id: 777)
    @steves_prefs    = Preferences.create(advanced_mode: true, id: 444, person_id: 777)
    @great_post      = Post.create(title: "Greatest Post", id: 555)
  end

  def test_engine_boolean
    assert JSONAPI::LinkBuilder.new(
      primary_resource_klass: MyEngine::Api::V1::PersonResource
    ).engine?, "MyEngine should be considered an Engine"

    assert JSONAPI::LinkBuilder.new(
      primary_resource_klass: ApiV2Engine::PersonResource
    ).engine?, "ApiV2 shouldn't be considered an Engine"

    refute JSONAPI::LinkBuilder.new(
      primary_resource_klass: Api::V1::PersonResource
    ).engine?, "Api shouldn't be considered an Engine"
  end

  def test_engine_name
    assert_equal MyEngine::Engine,
                 JSONAPI::LinkBuilder.new(
                   primary_resource_klass: MyEngine::Api::V1::PersonResource
                 ).engine

    assert_equal ApiV2Engine::Engine,
                 JSONAPI::LinkBuilder.new(
                   primary_resource_klass: ApiV2Engine::PersonResource
                 ).engine

    assert_nil JSONAPI::LinkBuilder.new(
      primary_resource_klass: Api::V1::PersonResource
    ).engine
  end

  def test_self_link_regular_app
    primary_resource_klass = Api::V1::PersonResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    source  = primary_resource_klass.new(@steve, nil)
    expected_link = "#{ @base_url }/api/v1/people/#{ source.id }"

    assert_equal expected_link, builder.self_link(source)
  end

  def test_self_link_regular_app_not_routed
    primary_resource_klass = Api::Secret::PostResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    source  = primary_resource_klass.new(@great_post, nil)


    # Should not warn if warn_on_missing_routes is false
    JSONAPI.configuration.warn_on_missing_routes = false
    primary_resource_klass._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.self_link(source)
      assert_nil link
    end
    assert_empty(err)

    # Test warn_on_missing_routes
    JSONAPI.configuration.warn_on_missing_routes = true
    primary_resource_klass._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.self_link(source)
      assert_nil link
    end
    assert_equal(err, "self_link for Api::Secret::PostResource could not be generated\n")

    # should only warn once
    builder = JSONAPI::LinkBuilder.new(config)
    _out, err = capture_subprocess_io do
      link = builder.self_link(source)
      assert_nil link
    end
    assert_empty(err)

  ensure
    JSONAPI.configuration.warn_on_missing_routes = true
  end

  def test_primary_resources_url_not_routed
    primary_resource_klass = Api::Secret::PostResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)

    # Should not warn if warn_on_missing_routes is false
    JSONAPI.configuration.warn_on_missing_routes = false
    primary_resource_klass._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.primary_resources_url
      assert_nil link
    end
    assert_empty(err)

    # Test warn_on_missing_routes
    JSONAPI.configuration.warn_on_missing_routes = true
    primary_resource_klass._warned_missing_route = false
    _out, err = capture_subprocess_io do
      link = builder.primary_resources_url
      assert_nil link
    end
    assert_equal(err, "primary_resources_url for Api::Secret::PostResource could not be generated\n")

    # should only warn once
    builder = JSONAPI::LinkBuilder.new(config)
    _out, err = capture_subprocess_io do
      link = builder.primary_resources_url
      assert_nil link
    end
    assert_empty(err)

  ensure
    JSONAPI.configuration.warn_on_missing_routes = true
  end

  def test_relationships_self_link_not_routed
    primary_resource_klass = Api::Secret::PostResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)

    source        = primary_resource_klass.new(@great_post, nil)

    relationship  = Api::Secret::PostResource._relationship(:author)

    # Should not warn if warn_on_missing_routes is false
    JSONAPI.configuration.warn_on_missing_routes = false
    relationship._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.relationships_self_link(source, relationship)
      assert_nil link
    end
    assert_empty(err)

    # Test warn_on_missing_routes
    JSONAPI.configuration.warn_on_missing_routes = true
    relationship._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.relationships_self_link(source, relationship)
      assert_nil link
    end
    assert_equal(err, "self_link for Api::Secret::PostResource.author(BelongsToOne) could not be generated\n")

    # should only warn once
    builder = JSONAPI::LinkBuilder.new(config)
    _out, err = capture_subprocess_io do
      link = builder.relationships_self_link(source, relationship)
      assert_nil link
    end
    assert_empty(err)

  ensure
    JSONAPI.configuration.warn_on_missing_routes = true
  end

  def test_relationships_related_link_not_routed
    primary_resource_klass = Api::Secret::PostResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)

    source        = primary_resource_klass.new(@great_post, nil)

    relationship  = Api::Secret::PostResource._relationship(:author)

    # Should not warn if warn_on_missing_routes is false
    JSONAPI.configuration.warn_on_missing_routes = false
    relationship._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.relationships_related_link(source, relationship)
      assert_nil link
    end
    assert_empty(err)

    # Test warn_on_missing_routes
    JSONAPI.configuration.warn_on_missing_routes = true
    relationship._warned_missing_route = false

    _out, err = capture_subprocess_io do
      link = builder.relationships_related_link(source, relationship)
      assert_nil link
    end
    assert_equal("related_link for Api::Secret::PostResource.author(BelongsToOne) could not be generated\n", err)

    # should only warn once
    builder = JSONAPI::LinkBuilder.new(config)
    _out, err = capture_subprocess_io do
      link = builder.relationships_related_link(source, relationship)
      assert_nil link
    end
    assert_empty(err)

  ensure
    JSONAPI.configuration.warn_on_missing_routes = true
  end

  def test_self_link_with_engine_app
    primary_resource_klass = ApiV2Engine::PersonResource
    primary_resource_klass._warned_missing_route = false

    config = {
      base_url: "#{ @base_url }",
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: ApiV2Engine::Engine.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    source  = primary_resource_klass.new(@steve, nil)
    expected_link = "#{ @base_url }/api_v2/people/#{ source.id }"

    assert_equal expected_link, builder.self_link(source)
  end

  def test_self_link_with_engine_namespaced_app
    primary_resource_klass = MyEngine::Api::V1::PersonResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    source  = primary_resource_klass.new(@steve, nil)
    expected_link = "#{ @base_url }/boomshaka/api/v1/people/#{ source.id }"

    assert_equal expected_link, builder.self_link(source)
  end

  def test_self_link_with_engine_app_and_camel_case_scope
    primary_resource_klass = MyEngine::AdminApi::V1::PersonResource

    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: primary_resource_klass,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    source  = primary_resource_klass.new(@steve, nil)
    expected_link = "#{ @base_url }/boomshaka/admin_api/v1/people/#{ source.id }"

    assert_equal expected_link, builder.self_link(source)
  end

  def test_primary_resources_url_for_regular_app
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/api/v1/people"

    assert_equal expected_link, builder.primary_resources_url
  end

  def test_primary_resources_url_for_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: ApiV2Engine::PersonResource,
      url_helpers: ApiV2Engine::Engine.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/api_v2/people"

    assert_equal expected_link, builder.primary_resources_url
  end

  def test_primary_resources_url_for_namespaced_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: MyEngine::Api::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    builder = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/boomshaka/api/v1/people"

    assert_equal expected_link, builder.primary_resources_url
  end

  def test_relationships_self_link_for_regular_app
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = Api::V1::PersonResource.new(@steve, nil)
    relationship  = Api::V1::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/api/v1/people/#{ @steve.id }/relationships/posts"

    assert_equal expected_link,
                 builder.relationships_self_link(source, relationship)
  end

  def test_relationships_self_link_for_regular_app_singleton
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = Api::V1::PreferencesResource.new(@steves_prefs, nil)
    relationship  = Api::V1::PreferencesResource._relationship(:author)
    expected_link = "#{ @base_url }/api/v1/preferences/relationships/author"

    assert_equal expected_link,
                 builder.relationships_self_link(source, relationship)
  end

  def test_relationships_related_link_for_regular_app_singleton
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = Api::V1::PreferencesResource.new(@steves_prefs, nil)
    relationship  = Api::V1::PreferencesResource._relationship(:author)
    expected_link = "#{ @base_url }/api/v1/preferences/author"

    assert_equal expected_link,
                 builder.relationships_related_link(source, relationship)
  end

  def test_relationships_self_link_for_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: ApiV2Engine::PersonResource,
      url_helpers: ApiV2Engine::Engine.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = ApiV2Engine::PersonResource.new(@steve, nil)
    relationship  = ApiV2Engine::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/api_v2/people/#{ @steve.id }/relationships/posts"

    assert_equal expected_link,
                 builder.relationships_self_link(source, relationship)
  end

  def test_relationships_self_link_for_namespaced_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: MyEngine::Api::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = MyEngine::Api::V1::PersonResource.new(@steve, nil)
    relationship  = MyEngine::Api::V1::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/boomshaka/api/v1/people/#{ @steve.id }/relationships/posts"

    assert_equal expected_link,
                 builder.relationships_self_link(source, relationship)
  end

  def test_relationships_related_link_for_regular_app
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = Api::V1::PersonResource.new(@steve, nil)
    relationship  = Api::V1::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/api/v1/people/#{ @steve.id }/posts"

    assert_equal expected_link,
                 builder.relationships_related_link(source, relationship)
  end

  def test_relationships_related_link_for_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: ApiV2Engine::PersonResource,
      url_helpers: ApiV2Engine::Engine.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = ApiV2Engine::PersonResource.new(@steve, nil)
    relationship  = ApiV2Engine::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/api_v2/people/#{ @steve.id }/posts"

    assert_equal expected_link,
                 builder.relationships_related_link(source, relationship)
  end

  def test_relationships_related_link_for_namespaced_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: MyEngine::Api::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = MyEngine::Api::V1::PersonResource.new(@steve, nil)
    relationship  = MyEngine::Api::V1::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/boomshaka/api/v1/people/#{ @steve.id }/posts"

    assert_equal expected_link,
                 builder.relationships_related_link(source, relationship)
  end

  def test_relationships_related_link_with_query_params
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    builder       = JSONAPI::LinkBuilder.new(config)
    source        = Api::V1::PersonResource.new(@steve, nil)
    relationship  = Api::V1::PersonResource._relationship(:posts)
    expected_link = "#{ @base_url }/api/v1/people/#{ @steve.id }/posts?page%5Blimit%5D=12&page%5Boffset%5D=0"
    query         = { page: { offset: 0, limit: 12 } }

    assert_equal expected_link,
                 builder.relationships_related_link(source, relationship, query)
  end

  def test_query_link_for_regular_app
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: Api::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/api/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_regular_app_with_camel_case_scope
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: AdminApi::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/admin_api/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_regular_app_with_dasherized_scope
    config = {
      base_url: @base_url,
      route_formatter: DasherizedRouteFormatter,
      primary_resource_klass: DasherizedNamespace::V1::PersonResource,
      url_helpers: TestApp.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/dasherized-namespace/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: ApiV2Engine::PersonResource,
      url_helpers: ApiV2Engine::Engine.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/api_v2/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_namespaced_engine
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: MyEngine::Api::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/boomshaka/api/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_engine_with_dasherized_scope
    config = {
      base_url: @base_url,
      route_formatter: DasherizedRouteFormatter,
      primary_resource_klass: MyEngine::DasherizedNamespace::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/boomshaka/dasherized-namespace/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end

  def test_query_link_for_engine_with_camel_case_scope
    config = {
      base_url: @base_url,
      route_formatter: @route_formatter,
      primary_resource_klass: MyEngine::AdminApi::V1::PersonResource,
      url_helpers: MyEngine::Engine.routes.url_helpers,
    }

    query         = { page: { offset: 0, limit: 12 } }
    builder       = JSONAPI::LinkBuilder.new(config)
    expected_link = "#{ @base_url }/boomshaka/admin_api/v1/people?page%5Blimit%5D=12&page%5Boffset%5D=0"

    assert_equal expected_link, builder.query_link(query)
  end
end
