# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

def set_content_type_header!
  @request.headers['Content-Type'] = JSONAPI::MEDIA_TYPE
end

class PostsControllerTest < ActionController::TestCase
  def setup
    super
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_links_include_relative_root
    Rails.application.config.relative_url_root = '/subdir'
    assert_cacheable_get :index
    assert json_response['data'][0]['links']['self'].include?('/subdir')
    Rails.application.config.relative_url_root = nil
  end

  def test_index
    assert_cacheable_get :index
    assert_response :success
    assert json_response['data'].is_a?(Array)
  end

  def test_index_includes
    assert_cacheable_get :index, params: { include: 'author,comments' }
    assert_response :success
    assert json_response['data'].is_a?(Array)
  end

  def test_accept_header_missing
    @request.headers['Accept'] = nil

    assert_cacheable_get :index
    assert_response :success
  end

  def test_accept_header_jsonapi_mixed
    @request.headers['Accept'] =
      "#{JSONAPI::MEDIA_TYPE},#{JSONAPI::MEDIA_TYPE};charset=test"

    assert_cacheable_get :index
    assert_response :success
  end

  def test_accept_header_jsonapi_modified
    @request.headers['Accept'] = "#{JSONAPI::MEDIA_TYPE};charset=test"

    assert_cacheable_get :index
    assert_response 406
    assert_equal 'Not acceptable', json_response['errors'][0]['title']
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.",
                 json_response['errors'][0]['detail']
  end

  def test_accept_header_jsonapi_multiple_modified
    @request.headers['Accept'] =
      "#{JSONAPI::MEDIA_TYPE};charset=test,#{JSONAPI::MEDIA_TYPE};charset=test"

    assert_cacheable_get :index
    assert_response 406
    assert_equal 'Not acceptable', json_response['errors'][0]['title']
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.",
                 json_response['errors'][0]['detail']
  end

  def test_accept_header_all
    @request.headers['Accept'] = "*/*"

    assert_cacheable_get :index
    assert_response :success
  end

  def test_accept_header_all_modified
    @request.headers['Accept'] = "*/*;q=0.8"

    assert_cacheable_get :index
    assert_response :success
  end

  def test_accept_header_not_jsonapi
    @request.headers['Accept'] = 'text/plain'

    assert_cacheable_get :index
    assert_response 406
    assert_equal 'Not acceptable', json_response['errors'][0]['title']
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.",
                 json_response['errors'][0]['detail']
  end

  def test_exception_class_allowlist
    original_allowlist = JSONAPI.configuration.exception_class_allowlist.dup
    $PostProcessorRaisesErrors = true
    # test that the operations dispatcher rescues the error when it
    # has not been added to the exception_class_allowlist
    assert_cacheable_get :index
    assert_response 500

    # test that the operations dispatcher does not rescue the error when it
    # has been added to the exception_class_allowlist
    JSONAPI.configuration.exception_class_allowlist << PostsController::SpecialError
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.exception_class_allowlist = original_allowlist
  end

  def test_allow_all_exceptions
    original_config = JSONAPI.configuration.allow_all_exceptions
    $PostProcessorRaisesErrors = true
    assert_cacheable_get :index
    assert_response 500

    JSONAPI.configuration.allow_all_exceptions = true
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.allow_all_exceptions = original_config
  end

  def test_exception_added_to_request_env
    original_config = JSONAPI.configuration.allow_all_exceptions
    $PostProcessorRaisesErrors = true
    refute @request.env['action_dispatch.exception']
    assert_cacheable_get :index
    assert @request.env['action_dispatch.exception']

    JSONAPI.configuration.allow_all_exceptions = true
    assert_cacheable_get :index
    assert @request.env['action_dispatch.exception']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.allow_all_exceptions = original_config
  end

  def test_exception_includes_backtrace_when_enabled
    original_config = JSONAPI.configuration.include_backtraces_in_errors
    $PostProcessorRaisesErrors = true

    JSONAPI.configuration.include_backtraces_in_errors = true
    assert_cacheable_get :index
    assert_response 500
    assert_includes @response.body, '"backtrace"', "expected backtrace in error body"

    JSONAPI.configuration.include_backtraces_in_errors = false
    assert_cacheable_get :index
    assert_response 500
    refute_includes @response.body, '"backtrace"', "expected backtrace in error body"
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.include_backtraces_in_errors = original_config
  end

  def test_exception_includes_application_backtrace_when_enabled
    original_config = JSONAPI.configuration.include_application_backtraces_in_errors
    $PostProcessorRaisesErrors = true

    JSONAPI.configuration.include_application_backtraces_in_errors = true
    assert_cacheable_get :index
    assert_response 500
    assert_includes @response.body, '"application_backtrace"', "expected application backtrace in error body"

    JSONAPI.configuration.include_application_backtraces_in_errors = false
    assert_cacheable_get :index
    assert_response 500
    refute_includes @response.body, '"application_backtrace"', "expected application backtrace in error body"
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.include_application_backtraces_in_errors = original_config
  end

  def test_on_server_error_block_callback_with_exception
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostProcessorRaisesErrors = true

    @controller.class.instance_variable_set(:@callback_message, "none")
    BaseController.on_server_error do
      @controller.class.instance_variable_set(:@callback_message, "Sent from block")
    end

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "Sent from block"

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
    assert_equal "Internal Server Error", json_response['errors'][0]['detail']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_method_callback_with_exception
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostProcessorRaisesErrors = true

    # ignores methods that don't exist
    @controller.class.on_server_error :set_callback_message, :a_bogus_method
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "Sent from method"

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_method_callback_with_exception_on_serialize
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostSerializerRaisesErrors = true

    # ignores methods that don't exist
    @controller.class.on_server_error :set_callback_message, :a_bogus_method
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal "Sent from method", @controller.class.instance_variable_get(:@callback_message)

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
  ensure
    $PostSerializerRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_callback_without_exception
    callback = Proc.new { @controller.class.instance_variable_set(:@callback_message, "Sent from block") }
    @controller.class.on_server_error callback
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "none"

    # test that it does not render error
    assert json_response.key?('data')
  ensure
    $PostProcessorRaisesErrors = false
  end

  def test_posts_index_include
    assert_cacheable_get :index, params: { filter: { id: '10,12' }, include: 'author' }
    assert_response :success
    assert_equal 2, json_response['data'].size
    assert_equal 2, json_response['included'].size
  end

  def test_index_filter_with_empty_result
    assert_cacheable_get :index, params: { filter: { title: 'post that does not exist' } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 0, json_response['data'].size
  end

  def test_index_filter_by_single_id
    assert_cacheable_get :index, params: { filter: { id: '1' } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_title
    assert_cacheable_get :index, params: { filter: { title: 'New post' } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_with_hash_values
    assert_cacheable_get :index, params: { filter: { search: { title: 'New post' } } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_array_of_ids
    assert_cacheable_get :index, params: { filter: { ids: '1,2' } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 2, json_response['data'].size
  end

  def test_index_filter_by_ids_and_include_related
    assert_cacheable_get :index, params: { filter: { id: '2' }, include: 'comments' }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_by_ids_and_include_related_different_type
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, include: 'author' }
    assert_response :success
    assert_equal 2, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_not_allowed
    JSONAPI.configuration.allow_filter = false
    assert_cacheable_get :index, params: { filter: { id: '1' } }
    assert_response :bad_request
  ensure
    JSONAPI.configuration.allow_filter = true
  end

  def test_cached_result_does_not_include_relationship_data
    JSONAPI.configuration.resource_cache = ActiveSupport::Cache::MemoryStore.new
    JSONAPI.configuration.default_caching = true

    get :show, params: { id: '1', include: 'author' }
    assert_response :success
    assert json_response['data']['relationships']['author']['data']

    get :show, params: { id: '1' }
    assert_response :success
    refute json_response['data']['relationships']['author']['data']
  ensure
    JSONAPI.configuration.resource_cache = nil
    JSONAPI.configuration.default_caching = false
  end

  def test_index_include_one_level_query_count
    assert_query_count(4) do
      assert_cacheable_get :index, params: { include: 'author' }
    end
    assert_response :success
  end

  def test_index_include_two_levels_query_count
    assert_query_count(6) do
      assert_cacheable_get :index, params: { include: 'author,author.comments' }
    end
    assert_response :success
  end

  def test_index_filter_by_ids_and_fields
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, fields: { posts: 'id,title,author' } }
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, links, attributes, relationships
    assert_equal 5, json_response['data'][0].size
    assert json_response['data'][0].key?('type')
    assert json_response['data'][0].key?('id')
    assert json_response['data'][0]['attributes'].key?('title')
    assert json_response['data'][0].key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_type
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, 'fields' => { 'posts' => 'id,title,author' } }
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, links, attributes, relationships
    assert_equal 5, json_response['data'][0].size
    assert json_response['data'][0].key?('type')
    assert json_response['data'][0].key?('id')
    assert json_response['data'][0]['attributes'].key?('title')
    assert json_response['data'][0].key?('links')
  end

  def test_index_filter_by_ids_and_fields_specify_unrelated_type
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, 'fields' => { 'currencies' => 'code' } }
    assert_response :bad_request
    assert_match /currencies is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_by_ids_and_fields_2
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, fields: { posts: 'author' } }
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, links, relationships
    assert_equal 4, json_response['data'][0].size
    assert json_response['data'][0].key?('type')
    assert json_response['data'][0].key?('id')
    assert json_response['data'][0]['relationships'].key?('author')
  end

  def test_filter_relationship_single
    assert_query_count(2) do
      assert_cacheable_get :index, params: { filter: { tags: '505,501' } }
    end
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_match /New post/, response.body
    assert_match /JR Solves your serialization woes!/, response.body
    assert_match /JR How To/, response.body
  end

  def test_filter_relationships_multiple
    assert_query_count(2) do
      assert_cacheable_get :index, params: { filter: { tags: '505,501', comments: '3' } }
    end
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_match /JR Solves your serialization woes!/, response.body
  end

  def test_filter_relationships_multiple_not_found
    assert_cacheable_get :index, params: { filter: { tags: '501', comments: '3' } }
    assert_response :success
    assert_equal 0, json_response['data'].size
  end

  def test_bad_filter
    assert_cacheable_get :index, params: { filter: { post_ids: '1,2' } }
    assert_response :bad_request
    assert_match /post_ids is not allowed/, response.body
  end

  def test_bad_filter_value_not_integer_array
    assert_cacheable_get :index, params: { filter: { id: 'asdfg' } }
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_integer
    assert_cacheable_get :index, params: { filter: { id: 'asdfg' } }
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_found_array
    assert_cacheable_get :index, params: { filter: { id: '5412333' } }
    assert_response :not_found
    assert_match /5412333 could not be found/, response.body
  end

  def test_bad_filter_value_not_found
    assert_cacheable_get :index, params: { filter: { id: '5412333' } }
    assert_response :not_found
    assert_match /5412333 could not be found/, json_response['errors'][0]['detail']
  end

  def test_field_not_supported
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, 'fields' => { 'posts' => 'id,title,rank,author' } }
    assert_response :bad_request
    assert_match /rank is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_resource_not_supported
    assert_cacheable_get :index, params: { filter: { id: '1,2' }, 'fields' => { 'posters' => 'id,title' } }
    assert_response :bad_request
    assert_match /posters is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_on_relationship
    assert_cacheable_get :index, params: { filter: { author: '1001' } }
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_blank
    assert_cacheable_get :index, params: { sort: '' }

    assert_response :success
  end

  def test_sorting_asc
    assert_cacheable_get :index, params: { sort: 'title' }

    assert_response :success
    assert_equal "A 1ST Post", json_response['data'][0]['attributes']['title']
  end

  def test_sorting_desc
    assert_cacheable_get :index, params: { sort: '-title' }

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['attributes']['title']
  end

  def test_sorting_by_multiple_fields
    assert_cacheable_get :index, params: { sort: 'title,body' }

    assert_response :success
    assert_equal '15', json_response['data'][0]['id']
  end

  def create_alphabetically_first_user_and_post
    author = Person.create(name: "Aardvark", date_joined: Time.now)
    author.posts.create(title: "My first post", body: "Hello World")
  end

  def test_sorting_by_relationship_field
    post = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: { sort: 'author.name' }

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'

    # Postgres sorts nulls last, whereas sqlite and mysql sort nulls first
    if ENV['DATABASE_URL'].starts_with?('postgres')
      assert_equal '17', json_response['data'][-1]['id'], 'nil is at the start'
      assert_equal post.id.to_s, json_response['data'][0]['id'], 'alphabetically first user is not first'
    else
      assert_equal '17', json_response['data'][0]['id'], 'nil is at the end'
      assert_equal post.id.to_s, json_response['data'][1]['id'], 'alphabetically first user is second'
    end
  end

  def test_desc_sorting_by_relationship_field
    post = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: { sort: '-author.name' }

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'

    # Postgres sorts nulls last, whereas sqlite and mysql sort nulls first
    if ENV['DATABASE_URL'].starts_with?('postgres')
      assert_equal '17', json_response['data'][0]['id'], 'nil is at the start'
      assert_equal post.id.to_s, json_response['data'][-1]['id']
    else
      assert_equal '17', json_response['data'][-1]['id'], 'nil is at the end'
      assert_equal post.id.to_s, json_response['data'][-2]['id'], 'alphabetically first user is second last'
    end
  end

  def test_sorting_by_relationship_field_include
    post = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: { include: 'author', sort: 'author.name' }

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'

    if ENV['DATABASE_URL'].starts_with?('postgres')
      assert_equal '17', json_response['data'][-1]['id'], 'nil is at the top'
      assert_equal post.id.to_s, json_response['data'][0]['id']
    else
      assert_equal '17', json_response['data'][0]['id'], 'nil is at the top'
      assert_equal post.id.to_s, json_response['data'][1]['id'], 'alphabetically first user is second'
    end
  end

  def test_invalid_sort_param
    assert_cacheable_get :index, params: { sort: 'asdfg' }

    assert_response :bad_request
    assert_match /asdfg is not a valid sort criteria for post/, response.body
  end

  def test_show_single_with_sort_disallowed
    JSONAPI.configuration.allow_sort = false
    assert_cacheable_get :index, params: { sort: 'title,body' }
    assert_response :bad_request
  ensure
    JSONAPI.configuration.allow_sort = true
  end

  def test_excluded_sort_param
    assert_cacheable_get :index, params: { sort: 'id' }

    assert_response :bad_request
    assert_match /id is not a valid sort criteria for post/, response.body
  end

  def test_show_single_no_includes
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['attributes']['title']
    assert_equal 'A body!!!', json_response['data']['attributes']['body']
    assert_nil json_response['included']
  end

  def test_show_does_not_include_records_count_in_meta
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_cacheable_get :show, params: { id: Post.first.id }
    assert_response :success
    assert_nil json_response['meta']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_show_does_not_include_pages_count_in_meta
    JSONAPI.configuration.top_level_meta_include_page_count = true
    assert_cacheable_get :show, params: { id: Post.first.id }
    assert_response :success
    assert_nil json_response['meta']
  ensure
    JSONAPI.configuration.top_level_meta_include_page_count = false
  end

  def test_show_single_with_has_one_include_included_exists
    assert_cacheable_get :show, params: { id: '1', include: 'author' }
    assert_response :success
    assert_equal 1, json_response['included'].size
    assert json_response['data']['relationships']['author'].has_key?('data'), 'Missing required data key'
    refute_nil json_response['data']['relationships']['author']['data'], 'Data should not be nil'
    refute json_response['data']['relationships']['tags'].has_key?('data'),
           'Not included relationships should not have data'
  end

  def test_show_single_with_has_one_include_included_does_not_exist
    assert_cacheable_get :show, params: { id: '1', include: 'section' }
    assert_response :success
    assert_nil json_response['included']
    assert json_response['data']['relationships']['section'].has_key?('data'), 'Missing required data key'
    assert_nil json_response['data']['relationships']['section']['data'], 'Data should be nil'
    refute json_response['data']['relationships']['tags'].has_key?('data'),
           'Not included relationships should not have data'
  end

  def test_show_single_with_has_many_include
    assert_cacheable_get :show, params: { id: '1', include: 'comments' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['attributes']['title']
    assert_equal 'A body!!!', json_response['data']['attributes']['body']
    assert_nil json_response['data']['relationships']['tags']['data']
    assert matches_array?([{ 'type' => 'comments', 'id' => '1' }, { 'type' => 'comments', 'id' => '2' }],
                          json_response['data']['relationships']['comments']['data'])
    assert_equal 2, json_response['included'].size
  end

  def test_includes_for_empty_relationships_shows_but_are_empty
    assert_cacheable_get :show, params: { id: '17', include: 'author,tags' }

    assert_response :success
    assert json_response['data']['relationships']['author'].has_key?('data'),
           'data key should exist for empty has_one relationship'
    assert_nil json_response['data']['relationships']['author']['data'], 'Data should be null'
    assert json_response['data']['relationships']['tags'].has_key?('data'),
           'data key should exist for empty has_many relationship'
    assert json_response['data']['relationships']['tags']['data'].is_a?(Array), 'Data should be array'
    assert json_response['data']['relationships']['tags']['data'].empty?, 'Data array should be empty'
  end

  def test_show_single_with_include_disallowed
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.default_allow_include_to_one = false
    JSONAPI.configuration.default_allow_include_to_many = false
    assert_cacheable_get :show, params: { id: '1', include: 'comments' }
    assert_response :bad_request
  ensure
    JSONAPI.configuration = original_config
  end

  def test_show_single_include_linkage
    JSONAPI.configuration.always_include_to_one_linkage_data = true

    assert_cacheable_get :show, params: { id: '17' }
    assert_response :success
    assert json_response['data']['relationships']['author'].has_key?('data'),
           'data key should exist for empty has_one relationship'
    assert_nil json_response['data']['relationships']['author']['data'], 'Data should be null'
    refute json_response['data']['relationships']['tags'].has_key?('data'),
           'data key should not exist for empty has_many relationship if not included'
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_index_single_include_linkage
    JSONAPI.configuration.always_include_to_one_linkage_data = true

    assert_cacheable_get :index, params: { filter: { id: '17' } }
    assert_response :success
    assert json_response['data'][0]['relationships']['author'].has_key?('data'),
           'data key should exist for empty has_one relationship'
    assert_nil json_response['data'][0]['relationships']['author']['data'], 'Data should be null'
    refute json_response['data'][0]['relationships']['tags'].has_key?('data'),
           'data key should not exist for empty has_many relationship if not included'
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_show_single_with_fields
    assert_cacheable_get :show, params: { id: '1', fields: { posts: 'author' } }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_nil json_response['data']['attributes']
  end

  def test_show_single_with_fields_string
    assert_cacheable_get :show, params: { id: '1', fields: 'author' }
    assert_response :bad_request
    assert_match /Fields must specify a type./, json_response['errors'][0]['detail']
  end

  def test_show_single_invalid_id_format
    assert_cacheable_get :show, params: { id: 'asdfg' }
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_show_single_missing_record
    assert_cacheable_get :show, params: { id: '5412333' }
    assert_response :not_found
    assert_match /record identified by 5412333 could not be found/, response.body
  end

  def test_show_malformed_fields_not_list
    assert_cacheable_get :show, params: { id: '1', 'fields' => '' }
    assert_response :bad_request
    assert_match /Fields must specify a type./, json_response['errors'][0]['detail']
  end

  def test_show_malformed_fields_type_not_list
    assert_cacheable_get :show, params: { id: '1', 'fields' => { 'posts' => '' } }
    assert_response :bad_request
    assert_match /nil is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_exception_class_allowlist
    original_allowlist = JSONAPI.configuration.exception_class_allowlist.dup
    $PostProcessorRaisesErrors = true
    # test that the operations dispatcher rescues the error when it
    # has not been added to the exception_class_allowlist
    assert_cacheable_get :index
    assert_response 500

    # test that the operations dispatcher does not rescue the error when it
    # has been added to the exception_class_allowlist
    JSONAPI.configuration.exception_class_allowlist << PostsController::SpecialError
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.exception_class_allowlist = original_allowlist
  end

  def test_allow_all_exceptions
    original_config = JSONAPI.configuration.allow_all_exceptions
    $PostProcessorRaisesErrors = true
    assert_cacheable_get :index
    assert_response 500

    JSONAPI.configuration.allow_all_exceptions = true
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.allow_all_exceptions = original_config
  end

  def test_exception_added_to_request_env
    original_config = JSONAPI.configuration.allow_all_exceptions
    $PostProcessorRaisesErrors = true
    refute @request.env['action_dispatch.exception']
    assert_cacheable_get :index
    assert @request.env['action_dispatch.exception']

    JSONAPI.configuration.allow_all_exceptions = true
    assert_cacheable_get :index
    assert @request.env['action_dispatch.exception']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.allow_all_exceptions = original_config
  end

  def test_exception_includes_backtrace_when_enabled
    original_config = JSONAPI.configuration.include_backtraces_in_errors
    $PostProcessorRaisesErrors = true

    JSONAPI.configuration.include_backtraces_in_errors = true
    assert_cacheable_get :index
    assert_response 500
    assert_includes @response.body, '"backtrace"', "expected backtrace in error body"

    JSONAPI.configuration.include_backtraces_in_errors = false
    assert_cacheable_get :index
    assert_response 500
    refute_includes @response.body, '"backtrace"', "expected backtrace in error body"
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.include_backtraces_in_errors = original_config
  end

  def test_exception_includes_application_backtrace_when_enabled
    original_config = JSONAPI.configuration.include_application_backtraces_in_errors
    $PostProcessorRaisesErrors = true

    JSONAPI.configuration.include_application_backtraces_in_errors = true
    assert_cacheable_get :index
    assert_response 500
    assert_includes @response.body, '"application_backtrace"', "expected application backtrace in error body"

    JSONAPI.configuration.include_application_backtraces_in_errors = false
    assert_cacheable_get :index
    assert_response 500
    refute_includes @response.body, '"application_backtrace"', "expected application backtrace in error body"
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.include_application_backtraces_in_errors = original_config
  end

  def test_on_server_error_block_callback_with_exception
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostProcessorRaisesErrors = true

    @controller.class.instance_variable_set(:@callback_message, "none")
    BaseController.on_server_error do
      @controller.class.instance_variable_set(:@callback_message, "Sent from block")
    end

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "Sent from block"

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
    assert_equal "Internal Server Error", json_response['errors'][0]['detail']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_method_callback_with_exception
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostProcessorRaisesErrors = true

    # ignores methods that don't exist
    @controller.class.on_server_error :set_callback_message, :a_bogus_method
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "Sent from method"

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_method_callback_with_exception_on_serialize
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    $PostSerializerRaisesErrors = true

    # ignores methods that don't exist
    @controller.class.on_server_error :set_callback_message, :a_bogus_method
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal "Sent from method", @controller.class.instance_variable_get(:@callback_message)

    # test that it renders the default server error response
    assert_equal "Internal Server Error", json_response['errors'][0]['title']
  ensure
    $PostSerializerRaisesErrors = false
    JSONAPI.configuration = original_config
  end

  def test_on_server_error_callback_without_exception
    callback = Proc.new { @controller.class.instance_variable_set(:@callback_message, "Sent from block") }
    @controller.class.on_server_error callback
    @controller.class.instance_variable_set(:@callback_message, "none")

    assert_cacheable_get :index
    assert_equal @controller.class.instance_variable_get(:@callback_message), "none"

    # test that it does not render error
    assert json_response.key?('data')
  ensure
    $PostProcessorRaisesErrors = false
  end

  def test_show_to_one_relationship
    assert_cacheable_get :show_relationship, params: { post_id: '1', relationship: 'author' }
    assert_response :success
    assert_hash_equals json_response,
                       { data: {
                           type: 'people',
                           id: '1001'
                         },
                         links: {
                           self: 'http://test.host/posts/1/relationships/author',
                           related: 'http://test.host/posts/1/author'
                         } }
  end

  def test_show_to_many_relationship
    assert_cacheable_get :show_relationship, params: { post_id: '2', relationship: 'tags' }
    assert_response :success
    assert_hash_equals json_response,
                       {
                         data: [
                           { type: 'tags', id: '505' }
                         ],
                         links: {
                           self: 'http://test.host/posts/2/relationships/tags',
                           related: 'http://test.host/posts/2/tags'
                         }
                       }
  end

  def test_show_to_many_relationship_invalid_id
    assert_cacheable_get :show_relationship, params: { post_id: '2,1', relationship: 'tags' }
    assert_response :bad_request
    assert_match /2,1 is not a valid value for id/, response.body
  end

  def test_show_to_one_relationship_nil
    assert_cacheable_get :show_relationship, params: { post_id: '17', relationship: 'author' }
    assert_response :success
    assert_hash_equals json_response,
                       {
                         data: nil,
                         links: {
                           self: 'http://test.host/posts/17/relationships/author',
                           related: 'http://test.host/posts/17/author'
                         }
                       }
  end

  def test_index_related_resources_sorted
    assert_cacheable_get :index_related_resources,
                         params: { person_id: '1001', relationship: 'posts', source: 'people', sort: 'title' }
    assert_response :success
    assert_equal 'JR How To', json_response['data'][0]['attributes']['title']
    assert_equal 'New post', json_response['data'][2]['attributes']['title']
    assert_cacheable_get :index_related_resources,
                         params: { person_id: '1001', relationship: 'posts', source: 'people', sort: '-title' }
    assert_response :success
    assert_equal 'New post', json_response['data'][0]['attributes']['title']
    assert_equal 'JR How To', json_response['data'][2]['attributes']['title']
  end

  def test_index_related_resources_default_sorted
    assert_cacheable_get :index_related_resources,
                         params: { person_id: '1001', relationship: 'posts', source: 'people' }
    assert_response :success
    assert_equal 'New post', json_response['data'][0]['attributes']['title']
    assert_equal 'JR How To', json_response['data'][2]['attributes']['title']
  end

  def test_index_related_resources_has_many_filtered
    assert_cacheable_get :index_related_resources,
                         params: { person_id: '1001', relationship: 'posts', source: 'people',
                                   filter: { title: 'JR How To' } }
    assert_response :success
    assert_equal 'JR How To', json_response['data'][0]['attributes']['title']
    assert_equal 1, json_response['data'].size
  end
end

class TagsControllerTest < ActionController::TestCase
  def test_tags_index
    assert_cacheable_get :index, params: { filter: { id: '506,507,508,509' } }
    assert_response :success
    assert_equal 4, json_response['data'].size
  end

  def test_tags_index_include_nested_tree
    assert_cacheable_get :index, params: { filter: { id: '506,508,509' }, include: 'posts.tags,posts.author.posts' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 4, json_response['included'].size
  end

  def test_tags_show_multiple
    assert_cacheable_get :show, params: { id: '506,507,508,509' }
    assert_response :bad_request
    assert_match /506,507,508,509 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_include
    assert_cacheable_get :show, params: { id: '506,507,508,509', include: 'posts.tags,posts.author.posts' }
    assert_response :bad_request
    assert_match /506,507,508,509 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids
    assert_cacheable_get :show, params: { id: '506,5099,509,50100' }
    assert_response :bad_request
    assert_match /506,5099,509,50100 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids_at_the_beginning
    assert_cacheable_get :show, params: { id: '5099,509,50100' }
    assert_response :bad_request
    assert_match /5099,509,50100 is not a valid value for id/, response.body
  end

  def test_nested_includes_sort
    assert_cacheable_get :index, params: { filter: { id: '506,507,508,509' },
                                           include: 'posts.tags,posts.author.posts',
                                           sort: 'name' }
    assert_response :success
    assert_equal 4, json_response['data'].size
    assert_equal 3, json_response['included'].size
  end
end

class PicturesControllerTest < ActionController::TestCase
  def test_pictures_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 8, json_response['data'].size
  end

  def test_pictures_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: { include: 'imageable' }
    assert_response :success
    assert_equal 8, json_response['data'].try(:size)
    assert_equal 5, json_response['included'].try(:size)
  end

  def test_pictures_index_with_polymorphic_to_one_linkage
    JSONAPI.configuration.always_include_to_one_linkage_data = true
    assert_cacheable_get :index
    assert_response :success
    assert_equal 8, json_response['data'].try(:size)
    assert_equal '3', json_response['data'][2]['id']
    assert_nil json_response['data'][2]['relationships']['imageable']['data']
    assert_equal 'products', json_response['data'][0]['relationships']['imageable']['data']['type']
    assert_equal '1', json_response['data'][0]['relationships']['imageable']['data']['id']
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_pictures_index_with_polymorphic_include_one_level_to_one_linkages
    JSONAPI.configuration.always_include_to_one_linkage_data = true
    assert_cacheable_get :index, params: { include: 'imageable' }
    assert_response :success
    assert_equal 8, json_response['data'].try(:size)
    assert_equal 5, json_response['included'].try(:size)
    assert_nil json_response['data'][2]['relationships']['imageable']['data']
    assert_equal 'products', json_response['data'][0]['relationships']['imageable']['data']['type']
    assert_equal '1', json_response['data'][0]['relationships']['imageable']['data']['id']
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_pictures_index_with_filter_documents
    assert_cacheable_get :index,
                         params: { include: 'imageable',
                                   filter: { 'imageable#documents.name': 'Management Through the Years' } }
    assert_response :success
    assert_equal 3, json_response['data'].try(:size)
    assert_equal 1, json_response['included'].try(:size)
  end
end

class DocumentsControllerTest < ActionController::TestCase
  def test_documents_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 5, json_response['data'].size
  end

  def test_documents_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: { include: 'pictures' }
    assert_response :success
    assert_equal 5, json_response['data'].size
    assert_equal 6, json_response['included'].size
  end
end

class ExpenseEntriesControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_text_error
    JSONAPI.configuration.use_text_errors = true
    assert_cacheable_get :index, params: { sort: 'not_in_record' }
    assert_response 400
    assert_equal 'INVALID_SORT_CRITERIA', json_response['errors'][0]['code']
  ensure
    JSONAPI.configuration.use_text_errors = false
  end

  def test_expense_entries_index
    assert_cacheable_get :index
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 2, json_response['data'].size
  end

  def test_expense_entries_show
    assert_cacheable_get :show, params: { id: 1 }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_expense_entries_show_include
    assert_cacheable_get :show, params: { id: 1, include: 'isoCurrency,employee' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_bad_include_missing_relationship
    assert_cacheable_get :show, params: { id: 1, include: 'isoCurrencies,employees' }
    assert_response :bad_request
    assert_match /isoCurrencies is not a valid includable relationship of expenseEntries/,
                 json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_bad_include_missing_sub_relationship
    assert_cacheable_get :show, params: { id: 1, include: 'isoCurrency,employee.post' }
    assert_response :bad_request
    assert_match /post is not a valid includable relationship of employees/, json_response['errors'][0]['detail']
  end

  def test_invalid_include
    assert_cacheable_get :index, params: { include: 'invalid../../../../' }
    assert_response :bad_request
    assert_match /invalid is not a valid includable relationship of expenseEntries/,
                 json_response['errors'][0]['detail']
  end

  def test_invalid_include_long_garbage_string
    assert_cacheable_get :index, params: { include: 'invalid.foo.bar.dfsdfs,dfsdfs.sdfwe.ewrerw.erwrewrew' }
    assert_response :bad_request
    assert_match /invalid is not a valid includable relationship of expenseEntries/,
                 json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_fields
    assert_cacheable_get :show,
                         params: { id: 1, include: 'isoCurrency,employee',
                                   'fields' => { 'expenseEntries' => 'transactionDate' } }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal ['transactionDate'], json_response['data']['attributes'].keys
    assert_equal 2, json_response['included'].size
  end

  def test_invalid_include
    assert_cacheable_get :index, params: { include: 'invalid../../../../' }
    assert_response :bad_request
    assert_match /invalid is not a valid includable relationship of expenseEntries/,
                 json_response['errors'][0]['detail']
  end

  def test_invalid_include_long_garbage_string
    assert_cacheable_get :index, params: { include: 'invalid.foo.bar.dfsdfs,dfsdfs.sdfwe.ewrerw.erwrewrew' }
    assert_response :bad_request
    assert_match /invalid is not a valid includable relationship of expenseEntries/,
                 json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_fields
    assert_cacheable_get :show,
                         params: { id: 1, include: 'isoCurrency,employee',
                                   'fields' => { 'expenseEntries' => 'transactionDate' } }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal ['transactionDate'], json_response['data']['attributes'].keys
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_fields_type_many
    assert_cacheable_get :show, params: { id: 1, include: 'isoCurrency,employee', 'fields' => { 'expenseEntries' => 'transactionDate',
                                                                                                'isoCurrencies' => 'id,name' } }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert json_response['data']['attributes'].key?('transactionDate')
    assert_equal 2, json_response['included'].size
  end
end

class IsoCurrenciesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_currencies_show
    assert_cacheable_get :show, params: { id: 'USD' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_currencies_primary_key_sort
    assert_cacheable_get :index, params: { sort: 'id' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'CAD', json_response['data'][0]['id']
    assert_equal 'EUR', json_response['data'][1]['id']
    assert_equal 'USD', json_response['data'][2]['id']
  end

  def test_currencies_code_sort
    assert_cacheable_get :index, params: { sort: 'code' }
    assert_response :bad_request
  end

  def test_currencies_json_key_underscored_sort
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key
    assert_cacheable_get :index, params: { sort: 'country_name' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country_name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country_name']
    assert_equal 'United States', json_response['data'][2]['attributes']['country_name']

    # reverse sort
    assert_cacheable_get :index, params: { sort: '-country_name' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['attributes']['country_name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country_name']
    assert_equal 'Canada', json_response['data'][2]['attributes']['country_name']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_dasherized_sort
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :index, params: { sort: 'country-name' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country-name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country-name']
    assert_equal 'United States', json_response['data'][2]['attributes']['country-name']

    # reverse sort
    assert_cacheable_get :index, params: { sort: '-country-name' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['attributes']['country-name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country-name']
    assert_equal 'Canada', json_response['data'][2]['attributes']['country-name']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_custom_json_key_sort
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    assert_cacheable_get :index, params: { sort: 'CountryName' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['CountryName']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['CountryName']
    assert_equal 'United States', json_response['data'][2]['attributes']['CountryName']

    # reverse sort
    assert_cacheable_get :index, params: { sort: '-CountryName' }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'United States', json_response['data'][0]['attributes']['CountryName']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['CountryName']
    assert_equal 'Canada', json_response['data'][2]['attributes']['CountryName']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_underscored_filter
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key
    assert_cacheable_get :index, params: { filter: { country_name: 'Canada' } }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country_name']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_camelized_key_filter
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    assert_cacheable_get :index, params: { filter: { 'countryName' => 'Canada' } }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['countryName']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_custom_json_key_filter
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    assert_cacheable_get :index, params: { filter: { 'CountryName' => 'Canada' } }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['CountryName']
  ensure
    JSONAPI.configuration = original_config
  end
end

class PeopleControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_invalid_filter_value
    assert_cacheable_get :index, params: { filter: { name: 'L' } }
    assert_response :bad_request
  end

  def test_invalid_filter_value_for_index_related_resources
    assert_cacheable_get :index_related_resources, params: {
      hair_cut_id: 1,
      relationship: 'people',
      source: 'hair_cuts',
      filter: { name: 'L' }
    }

    assert_response :bad_request
  end

  def test_valid_filter_value
    assert_cacheable_get :index, params: { filter: { name: 'Joe Author' } }
    assert_response :success
    assert_equal json_response['data'].size, 1
    assert_equal '1001', json_response['data'][0]['id']
    assert_equal 'Joe Author', json_response['data'][0]['attributes']['name']
  end

  def test_show_related_resource_no_namespace
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    JSONAPI.configuration.route_format = :underscored_key
    assert_cacheable_get :show_related_resource, params: { post_id: '2', relationship: 'author', source: 'posts' }
    assert_response :success

    assert_hash_equals(
      {
        "data" => {
          "id" => "1001",
          "type" => "people",
          "links" => {
            "self" => "http://test.host/people/1001"
          },
          "attributes" => {
            "name" => "Joe Author",
            "email" => "joe@xyz.fake",
            "date-joined" => "2013-08-07 16:25:00 -0400"
          },
          "relationships" => {
            "comments" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/comments",
                "related" => "http://test.host/people/1001/comments"
              }
            },
            "posts" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/posts",
                "related" => "http://test.host/people/1001/posts"
              }
            },
            "preferences" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/preferences",
                "related" => "http://test.host/people/1001/preferences"
              }
            },
            "vehicles" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/vehicles",
                "related" => "http://test.host/people/1001/vehicles"
              }
            },
            "hair-cut" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/hair_cut",
                "related" => "http://test.host/people/1001/hair_cut"
              }
            },
            "expense-entries" => {
              "links" => {
                "self" => "http://test.host/people/1001/relationships/expense_entries",
                "related" => "http://test.host/people/1001/expense_entries"
              }
            }
          }
        }
      },
      json_response
    )
  ensure
    JSONAPI.configuration = original_config
  end

  def test_show_related_resource_includes
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    JSONAPI.configuration.route_format = :underscored_key
    assert_cacheable_get :show_related_resource,
                         params: { post_id: '2', relationship: 'author', source: 'posts', include: 'posts' }
    assert_response :success
    assert_equal 'posts', json_response['included'][0]['type']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_show_related_resource_nil
    assert_cacheable_get :show_related_resource, params: { post_id: '17', relationship: 'author', source: 'posts' }
    assert_response :success
    assert_hash_equals json_response,
                       {
                         data: nil
                       }
  end
end

class BooksControllerTest < ActionController::TestCase
  def test_books_include_correct_type
    $test_user = Person.find(1001)
    assert_cacheable_get :index, params: { filter: { id: '1' }, include: 'authors' }
    assert_response :success
    assert_equal 'authors', json_response['included'][0]['type']
  end

  def test_index_with_caching_enabled_uses_context
    assert_cacheable_get :index
    assert_response :success
    assert json_response['data'][0]['attributes']['title'] = 'Title'
  end
end

class Api::V5::PostsControllerTest < ActionController::TestCase
  def test_show_post_no_relationship_routes_exludes_relationships
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_nil json_response['data']['relationships']
  end

  def test_exclude_resource_links
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_equal 1, json_response['data']['links'].length

    Api::V5::PostResource.exclude_links :default
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_nil json_response['data']['links']

    Api::V5::PostResource.exclude_links [:self]
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_nil json_response['data']['links']

    Api::V5::PostResource.exclude_links :none
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_equal 1, json_response['data']['links'].length
  ensure
    Api::V5::PostResource.exclude_links :none
  end

  def test_show_post_no_relationship_route_include
    get :show, params: { id: '1', include: 'author' }
    assert_response :success
    assert_equal '1001', json_response['data']['relationships']['author']['data']['id']
    assert_nil json_response['data']['relationships']['tags']
    assert_equal '1001', json_response['included'][0]['id']
    assert_equal 'people', json_response['included'][0]['type']
    assert_equal 'joe@xyz.fake', json_response['included'][0]['attributes']['email']
  end
end

class Api::V5::AuthorsControllerTest < ActionController::TestCase
  def test_get_person_as_author
    assert_cacheable_get :index, params: { filter: { id: '1001' } }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1001', json_response['data'][0]['id']
    assert_equal 'authors', json_response['data'][0]['type']
    assert_equal 'Joe Author', json_response['data'][0]['attributes']['name']
    assert_nil json_response['data'][0]['attributes']['email']
  end

  def test_show_person_as_author
    assert_cacheable_get :show, params: { id: '1001' }
    assert_response :success
    assert_equal '1001', json_response['data']['id']
    assert_equal 'authors', json_response['data']['type']
    assert_equal 'Joe Author', json_response['data']['attributes']['name']
    assert_nil json_response['data']['attributes']['email']
  end

  def test_get_person_as_author_by_name_filter
    assert_cacheable_get :index, params: { filter: { name: 'thor' } }
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal '1001', json_response['data'][0]['id']
    assert_equal 'Joe Author', json_response['data'][0]['attributes']['name']
  end

  def test_meta_serializer_options
    JSONAPI.configuration.json_key_format = :camelized_key

    Api::V5::AuthorResource.class_eval do
      def meta(options)
        {
          fixed: 'Hardcoded value',
          computed: "#{self.class._type.to_s}: #{options[:serializer].link_builder.self_link(self)}",
          computed_foo: options[:serialization_options][:foo],
          options[:serializer].format_key('test_key') => 'test value'
        }
      end
    end

    assert_cacheable_get :show, params: { id: '1001' }
    assert_response :success
    assert_equal '1001', json_response['data']['id']
    assert_equal 'Hardcoded value', json_response['data']['meta']['fixed']
    assert_equal 'authors: http://test.host/api/v5/authors/1001', json_response['data']['meta']['computed']
    assert_equal 'bar', json_response['data']['meta']['computed_foo']
    assert_equal 'test value', json_response['data']['meta']['testKey']
  ensure
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V5::AuthorResource.class_eval do
      def meta(options)
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  def test_meta_serializer_hash_data
    JSONAPI.configuration.json_key_format = :camelized_key

    Api::V5::AuthorResource.class_eval do
      def meta(options)
        {
          custom_hash: {
            fixed: 'Hardcoded value',
            computed: "#{self.class._type.to_s}: #{options[:serializer].link_builder.self_link(self)}",
            computed_foo: options[:serialization_options][:foo],
            options[:serializer].format_key('test_key') => 'test value'
          }
        }
      end
    end

    assert_cacheable_get :show, params: { id: '1001' }
    assert_response :success
    assert_equal '1001', json_response['data']['id']
    assert_equal 'Hardcoded value', json_response['data']['meta']['custom_hash']['fixed']
    assert_equal 'authors: http://test.host/api/v5/authors/1001',
                 json_response['data']['meta']['custom_hash']['computed']
    assert_equal 'bar', json_response['data']['meta']['custom_hash']['computed_foo']
    assert_equal 'test value', json_response['data']['meta']['custom_hash']['testKey']
  ensure
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V5::AuthorResource.class_eval do
      def meta(options)
        # :nocov:
        {}
        # :nocov:
      end
    end
  end
end

class BreedsControllerTest < ActionController::TestCase
  # Note: Breed names go through the TitleValueFormatter

  def test_poro_index
    get :index
    assert_response :success
    assert_equal '0', json_response['data'][0]['id']
    assert_equal 'Persian', json_response['data'][0]['attributes']['name']
  end

  def test_poro_show
    get :show, params: { id: '0' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '0', json_response['data']['id']
    assert_equal 'Persian', json_response['data']['attributes']['name']
  end

  def test_poro_show_multiple
    assert_cacheable_get :show, params: { id: '0,2' }

    assert_response :bad_request
    assert_match /0,2 is not a valid value for id/, response.body
  end
end

class Api::V2::PreferencesControllerTest < ActionController::TestCase
  def test_show_singleton_resource_without_id
    $test_user = Person.find(1001)

    assert_cacheable_get :show
    assert_response :success
  end
end

class Api::V1::PostsControllerTest < ActionController::TestCase
  def test_show_post_namespaced
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert_equal 'http://test.host/api/v1/posts/1/relationships/writer',
                 json_response['data']['relationships']['writer']['links']['self']
  end

  def test_show_post_namespaced_include
    assert_cacheable_get :show, params: { id: '1', include: 'writer' }
    assert_response :success
    assert_equal '1001', json_response['data']['relationships']['writer']['data']['id']
    assert_nil json_response['data']['relationships']['tags']
    assert_equal '1001', json_response['included'][0]['id']
    assert_equal 'writers', json_response['included'][0]['type']
    assert_equal 'joe@xyz.fake', json_response['included'][0]['attributes']['email']
  end

  def test_index_filter_on_relationship_namespaced
    assert_cacheable_get :index, params: { filter: { writer: '1001' } }
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_desc_namespaced
    assert_cacheable_get :index, params: { sort: '-title' }

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['attributes']['title']
  end
end

class FactsControllerTest < ActionController::TestCase
  def test_type_formatting
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    assert_cacheable_get :show, params: { id: '1' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Jane Author', json_response['data']['attributes']['spouseName']
    assert_equal 'First man to run across Antartica.', json_response['data']['attributes']['bio']
    assert_equal (23.89 / 45.6).round(5), json_response['data']['attributes']['qualityRating'].round(5)
    assert_equal '47000.56', json_response['data']['attributes']['salary']
    assert_equal '2013-08-07T20:25:00.000Z', json_response['data']['attributes']['dateTimeJoined']
    assert_equal '1965-06-30', json_response['data']['attributes']['birthday']
    assert_equal '2000-01-01T20:00:00.000Z', json_response['data']['attributes']['bedtime']
    assert_equal 'abc', json_response['data']['attributes']['photo']
    assert_equal false, json_response['data']['attributes']['cool']
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V2::BooksControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :dasherized_key
    $test_user = Person.find(1001)
  end

  def after_teardown
    Api::V2::BookResource.paginator :offset
  end

  def test_books_offset_pagination_no_params
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_record_count_in_meta
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_cacheable_get :index, params: { include: 'book-comments' }
    JSONAPI.configuration.top_level_meta_include_record_count = false

    assert_response :success
    assert_equal 901, json_response['meta']['record-count']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_page_count_in_meta
    Api::V2::BookResource.paginator :paged
    JSONAPI.configuration.top_level_meta_include_page_count = true
    assert_cacheable_get :index, params: { include: 'book-comments' }
    JSONAPI.configuration.top_level_meta_include_page_count = false

    assert_response :success
    assert_equal 91, json_response['meta']['page-count']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_no_page_count_in_meta_with_none_paginator
    Api::V2::BookResource.paginator :none
    JSONAPI.configuration.top_level_meta_include_page_count = true
    assert_cacheable_get :index, params: { include: 'book-comments' }
    JSONAPI.configuration.top_level_meta_include_page_count = false

    assert_response :success
    assert_nil json_response['meta']['page-count']
    assert_equal 901, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_record_count_in_meta_custom_name
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.top_level_meta_record_count_key = 'total_records'

    assert_cacheable_get :index, params: { include: 'book-comments' }
    JSONAPI.configuration.top_level_meta_include_record_count = false
    JSONAPI.configuration.top_level_meta_record_count_key = :record_count

    assert_response :success
    assert_equal 901, json_response['meta']['total-records']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_page_count_in_meta_custom_name
    Api::V2::BookResource.paginator :paged
    JSONAPI.configuration.top_level_meta_include_page_count = true
    JSONAPI.configuration.top_level_meta_page_count_key = 'total_pages'

    assert_cacheable_get :index, params: { include: 'book-comments' }
    JSONAPI.configuration.top_level_meta_include_page_count = false
    JSONAPI.configuration.top_level_meta_page_count_key = :page_count

    assert_response :success
    assert_equal 91, json_response['meta']['total-pages']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_no_params_includes_query_count_one_level
    Api::V2::BookResource.paginator :offset

    assert_query_count(5) do
      assert_cacheable_get :index, params: { include: 'book-comments' }
    end
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_no_params_includes_query_count_two_levels
    Api::V2::BookResource.paginator :offset

    assert_query_count(7) do
      assert_cacheable_get :index, params: { include: 'book-comments,book-comments.author' }
    end
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: { offset: 50, limit: 12 } }
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_bad_page_param
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: { offset_bad: 50, limit: 12 } }
    assert_response :bad_request
    assert_match /offset_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: { offset: 50, limit: 1000 } }
    assert_response :bad_request
    assert_match /Limit exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: { offset: 50, limit: -1 } }
    assert_response :bad_request
    assert_match /-1 is not a valid value for limit page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_offset_less_than_zero
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: { offset: -1, limit: 20 } }
    assert_response :bad_request
    assert_match /-1 is not a valid value for offset page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_invalid_page_format
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: { page: 50 }
    assert_response :bad_request
    assert_match /Invalid Page Object./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_no_params
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_paged_pagination_no_page
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: { size: 12 } }
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_paged_pagination
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: { number: 3, size: 12 } }
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 24', json_response['data'][0]['attributes']['title']
  end

  def test_books_paged_pagination_bad_page_param
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: { number_bad: 50, size: 12 } }
    assert_response :bad_request
    assert_match /number_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: { number: 50, size: 1000 } }
    assert_response :bad_request
    assert_match /size exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: { number: 50, size: -1 } }
    assert_response :bad_request
    assert_match /-1 is not a valid value for size page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_invalid_page_format_incorrect
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: 'qwerty' }
    assert_response :bad_request
    assert_match /0 is not a valid value for number page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_invalid_page_format_interpret_int
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: { page: 3 }
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 20', json_response['data'][0]['attributes']['title']
  end

  def test_books_included_paged
    Api::V2::BookResource.paginator :offset

    assert_query_count(5) do
      assert_cacheable_get :index, params: { filter: { id: '0' }, include: 'book-comments' }
      assert_response :success
      assert_equal 1, json_response['data'].size
      assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    end
  end

  def test_books_banned_non_book_admin
    $test_user = Person.find(1001)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(3) do
      assert_cacheable_get :index, params: { page: { offset: 50, limit: 12 } }
      assert_response :success
      assert_equal 12, json_response['data'].size
      assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
      assert_equal 901, json_response['meta']['record-count']
    end
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_includes_switched
    $test_user = Person.find(1001)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(5) do
      assert_cacheable_get :index, params: { page: { offset: 0, limit: 12 }, include: 'book-comments' }
      assert_response :success
      assert_equal 12, json_response['data'].size
      assert_equal 130, json_response['included'].size
      assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
      assert_equal 26, json_response['data'][0]['relationships']['book-comments']['data'].size
      assert_equal 'book-comments', json_response['included'][0]['type']
      assert_equal 901, json_response['meta']['record-count']
    end
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_includes_nested_includes
    $test_user = Person.find(1001)
    JSONAPI.configuration.top_level_meta_include_record_count = true
    Api::V2::BookResource.paginator :offset
    assert_query_count(7) do
      assert_cacheable_get :index, params: { page: { offset: 0, limit: 12 }, include: 'book-comments.author' }
      assert_response :success
      assert_equal 12, json_response['data'].size
      assert_equal 132, json_response['included'].size
      assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
      assert_equal 901, json_response['meta']['record-count']
    end
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_admin
    $test_user = Person.find(1005)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(3) do
      assert_cacheable_get :index, params: { page: { offset: 50, limit: 12 }, filter: { banned: 'true' } }
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 651', json_response['data'][0]['attributes']['title']
    assert_equal 99, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_not_banned_admin
    $test_user = Person.find(1005)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(3) do
      assert_cacheable_get :index,
                           params: { page: { offset: 50, limit: 12 }, filter: { banned: 'false' },
                                     fields: { books: 'id,title' } }
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_overlapped
    $test_user = Person.find(1001)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(3) do
      assert_cacheable_get :index, params: { page: { offset: 590, limit: 20 } }
    end
    assert_response :success
    assert_equal 20, json_response['data'].size
    assert_equal 'Book 590', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_included_exclude_unapproved
    $test_user = Person.find(1001)
    Api::V2::BookResource.paginator :none

    assert_query_count(4) do
      assert_cacheable_get :index, params: { filter: { id: '0,1,2,3,4' }, include: 'book-comments' }
    end
    assert_response :success
    assert_equal 5, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 130, json_response['included'].size
    assert_equal 26, json_response['data'][0]['relationships']['book-comments']['data'].size
  end

  def test_books_included_all_comments_for_admin
    $test_user = Person.find(1005)
    Api::V2::BookResource.paginator :none

    assert_cacheable_get :index, params: { filter: { id: '0,1,2,3,4' }, include: 'book-comments' }
    assert_response :success
    assert_equal 5, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 255, json_response['included'].size
    assert_equal 51, json_response['data'][0]['relationships']['book-comments']['data'].size
  end

  def test_books_filter_by_book_comment_id_limited_user
    $test_user = Person.find(1001)
    assert_cacheable_get :index, params: { filter: { book_comments: '0,52' } }
    assert_response :success
    assert_equal 1, json_response['data'].size
  end

  def test_books_filter_by_book_comment_id_admin_user
    $test_user = Person.find(1005)
    assert_cacheable_get :index, params: { filter: { book_comments: '0,52' } }
    assert_response :success
    assert_equal 2, json_response['data'].size
  end

  def test_index_related_resources_pagination
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index_related_resources,
                         params: { author_id: '1003', relationship: 'books', source: 'api/v2/authors' }
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 3, json_response['links'].size
    assert_equal 'http://test.host/api/v2/authors/1003/books?page%5Blimit%5D=10&page%5Boffset%5D=0',
                 json_response['links']['first']
  end
end

class Api::V2::BookCommentsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V2::BookCommentResource.paginator :none
    $test_user = Person.find(1001)
  end

  def test_book_comments_all_for_admin
    $test_user = Person.find(1005)
    assert_query_count(2) do
      assert_cacheable_get :index
    end
    assert_response :success
    assert_equal 255, json_response['data'].size
  end

  def test_book_comments_unapproved_context_based
    $test_user = Person.find(1005)
    assert_query_count(2) do
      assert_cacheable_get :index, params: { filter: { approved: 'false' } }
    end
    assert_response :success
    assert_equal 125, json_response['data'].size
  end

  def test_book_comments_exclude_unapproved_context_based
    $test_user = Person.find(1001)
    assert_query_count(2) do
      assert_cacheable_get :index
    end
    assert_response :success
    assert_equal 130, json_response['data'].size
  end
end

class Api::V4::PostsControllerTest < ActionController::TestCase
  def test_warn_on_joined_to_many
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.warn_on_performance_issues = true
    _out, err = capture_subprocess_io do
      get :index, params: { fields: { posts: 'id,title' } }
      assert_response :success
    end
    assert_match(
      /Performance issue detected: `Api::V4::PostResource.records` returned non-normalized results in `Api::V4::PostResource.find_fragments`\./, err
    )

    JSONAPI.configuration.warn_on_performance_issues = false
    _out, err = capture_subprocess_io do
      get :index, params: { fields: { posts: 'id,title' } }
      assert_response :success
    end
    # On older Ruby/Rails combinations, there may be deprecation warnings
    # but we should not see the performance issue warning
    refute_match(/Performance issue detected/, err)
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V4::BooksControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_books_offset_pagination_meta
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    Api::V4::BookResource.paginator :offset
    assert_cacheable_get :index, params: { page: { offset: 50, limit: 12 } }
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['recordCount']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_inherited_pagination
    assert_equal :paged, Api::V4::BiggerBookResource._paginator
  end

  def test_books_operation_links
    original_config = JSONAPI.configuration.dup
    Api::V4::BookResource.paginator :offset
    assert_cacheable_get :index, params: { page: { offset: 50, limit: 12 } }
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 4, json_response['links'].size
    # assert_equal 'https://test_corp.com', json_response['links']['spec']
  ensure
    JSONAPI.configuration = original_config
  end
end

class CategoriesControllerTest < ActionController::TestCase
  def test_index_default_filter
    assert_cacheable_get :index
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 3, json_response['data'].size
  end

  def test_index_default_filter_override
    assert_cacheable_get :index, params: { filter: { status: 'inactive' } }
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 4, json_response['data'].size
  end
end

class Api::V1::PlanetsControllerTest < ActionController::TestCase
end

class Api::V1::MoonsControllerTest < ActionController::TestCase
  def test_show_related_resource
    assert_cacheable_get :show_related_resource,
                         params: { crater_id: 'S56D', relationship: 'moon', source: "api/v1/craters" }
    assert_response :success
    assert_hash_equals({
                         data: {
                           id: "1",
                           type: "moons",
                           links: { self: "http://test.host/api/v1/moons/1" },
                           attributes: { name: "Titan", description: "Best known of the Saturn moons." },
                           relationships: {
                             planet: { links: { self: "http://test.host/api/v1/moons/1/relationships/planet",
                                                related: "http://test.host/api/v1/moons/1/planet" } },
                             craters: { links: { self: "http://test.host/api/v1/moons/1/relationships/craters",
                                                 related: "http://test.host/api/v1/moons/1/craters" } }
                           }
                         }
                       }, json_response)
  end

  def test_show_related_resource_to_one_linkage_data
    JSONAPI.configuration.always_include_to_one_linkage_data = true

    assert_cacheable_get :show_related_resource,
                         params: { crater_id: 'S56D', relationship: 'moon', source: "api/v1/craters" }
    assert_response :success
    assert_hash_equals({
                         data: {
                           id: "1",
                           type: "moons",
                           links: { self: "http://test.host/api/v1/moons/1" },
                           attributes: { name: "Titan", description: "Best known of the Saturn moons." },
                           relationships: {
                             planet: { links: { self: "http://test.host/api/v1/moons/1/relationships/planet",
                                                related: "http://test.host/api/v1/moons/1/planet" },
                                       data: { type: "planets", id: "1" } },
                             craters: { links: { self: "http://test.host/api/v1/moons/1/relationships/craters",
                                                 related: "http://test.host/api/v1/moons/1/craters" } }
                           }
                         }
                       }, json_response)
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end

  def test_index_related_resources_with_select_some_db_columns
    Api::V1::MoonResource.paginator :paged
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :index_related_resources,
                         params: { planet_id: '1', relationship: 'moons', source: 'api/v1/planets' }
    assert_response :success
    assert_equal 1, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V1::CratersControllerTest < ActionController::TestCase
  def test_show_single
    assert_cacheable_get :show, params: { id: 'S56D' }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'S56D', json_response['data']['attributes']['code']
    assert_equal 'Very large crater', json_response['data']['attributes']['description']
    assert_nil json_response['included']
  end

  def test_index_related_resources
    assert_cacheable_get :index_related_resources,
                         params: { moon_id: '1', relationship: 'craters', source: "api/v1/moons" }
    assert_response :success
    assert_hash_equals({
                         data: [
                           {
                             id: "A4D3",
                             type: "craters",
                             links: { self: "http://test.host/api/v1/craters/A4D3" },
                             attributes: { code: "A4D3", description: "Small crater" },
                             relationships: { moon: { links: {
                               self: "http://test.host/api/v1/craters/A4D3/relationships/moon", related: "http://test.host/api/v1/craters/A4D3/moon"
                             } } }
                           },
                           {
                             id: "S56D",
                             type: "craters",
                             links: { self: "http://test.host/api/v1/craters/S56D" },
                             attributes: { code: "S56D", description: "Very large crater" },
                             relationships: { moon: { links: {
                               self: "http://test.host/api/v1/craters/S56D/relationships/moon", related: "http://test.host/api/v1/craters/S56D/moon"
                             } } }
                           }
                         ]
                       }, json_response)
  end

  def test_index_related_resources_filtered
    $test_user = Person.find(1001)
    assert_cacheable_get :index_related_resources,
                         params: {
                           moon_id: '1',
                           relationship: 'craters',
                           source: "api/v1/moons",
                           filter: { description: 'Small crater' }
                         }

    assert_response :success
    assert_hash_equals({
                         data: [
                           {
                             id: "A4D3",
                             type: "craters",
                             links: { self: "http://test.host/api/v1/craters/A4D3" },
                             attributes: { code: "A4D3", description: "Small crater" },
                             relationships: {
                               moon: {
                                 links: {
                                   self: "http://test.host/api/v1/craters/A4D3/relationships/moon",
                                   related: "http://test.host/api/v1/craters/A4D3/moon"
                                 }
                               }
                             }
                           }
                         ]
                       }, json_response)
  end

  def test_show_relationship
    assert_cacheable_get :show_relationship, params: { crater_id: 'S56D', relationship: 'moon' }

    assert_response :success
    assert_equal "moons", json_response['data']['type']
    assert_equal "1", json_response['data']['id']
  end
end

class CarsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end
end

class VehiclesControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_STI_index_returns_all_types
    assert_cacheable_get :index
    assert_response :success
    assert_equal 'cars', json_response['data'][0]['type']
    assert_equal 'boats', json_response['data'][1]['type']
  end

  def test_immutable_create_not_supported
    set_content_type_header!

    assert_raises ActionController::UrlGenerationError do
      post :create, params: {
        data: {
          type: 'cars',
          attributes: {
            make: 'Toyota',
            model: 'Corrola',
            serialNumber: 'dsvffsfv',
            driveLayout: 'FWD'
          }
        }
      }
    end
  end

  def test_immutable_update_not_supported
    set_content_type_header!

    assert_raises ActionController::UrlGenerationError do
      patch :update, params: {
        data: {
          id: '1',
          type: 'cars',
          attributes: {
            make: 'Toyota',
          }
        }
      }
    end
  end
end

class Api::V7::ClientsControllerTest < ActionController::TestCase
  def test_get_namespaced_model_not_matching_resource_using_model_hint
    assert_cacheable_get :index
    assert_response :success
    assert_equal 'clients', json_response['data'][0]['type']
  ensure
    Api::V7::ClientResource._model_hints['api/v7/customer'] = 'clients'
  end

  def test_get_namespaced_model_not_matching_resource_not_using_model_hint
    Api::V7::ClientResource._model_hints.delete('api/v7/customer')
    assert_cacheable_get :index
    assert_response :success
    assert_equal 'customers', json_response['data'][0]['type']
  ensure
    Api::V7::ClientResource._model_hints['api/v7/customer'] = 'clients'
  end
end

class Api::V7::CustomersControllerTest < ActionController::TestCase
  def test_get_namespaced_model_matching_resource
    assert_cacheable_get :index
    assert_response :success
    assert_equal 'customers', json_response['data'][0]['type']
  end
end

class Api::V7::CategoriesControllerTest < ActionController::TestCase
  def test_uncaught_error_in_controller_translated_to_internal_server_error
    get :show, params: { id: '1' }
    assert_response 500
    assert_match /Internal Server Error/, json_response['errors'][0]['detail']
  end

  def test_not_allowed_error_in_controller
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_allowlist = []
    get :show, params: { id: '1' }
    assert_response 500
    assert_match /Internal Server Error/, json_response['errors'][0]['detail']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_allowed_error_in_controller
    original_config = JSONAPI.configuration.dup
    $PostProcessorRaisesErrors = true
    JSONAPI.configuration.exception_class_allowlist = [PostsController::SubSpecialError]
    assert_raises PostsController::SubSpecialError do
      assert_cacheable_get :show, params: { id: '1' }
    end
  ensure
    JSONAPI.configuration = original_config
    $PostProcessorRaisesErrors = false
  end
end

class Api::V6::PostsControllerTest < ActionController::TestCase
  def test_caching_with_join_from_resource_with_sql_fragment
    assert_cacheable_get :index, params: { include: 'section' }
    assert_response :success
  end
end

class Api::V6::SectionsControllerTest < ActionController::TestCase
  def test_caching_with_join_to_resource_with_sql_fragment
    assert_cacheable_get :index, params: { include: 'posts' }
    assert_response :success
  end
end

class AuthorsControllerTest < ActionController::TestCase
  def test_show_author_recursive
    assert_cacheable_get :show, params: { id: '1002', include: 'books.authors' }
    assert_response :success
    assert_equal '1002', json_response['data']['id']
    assert_equal 'authors', json_response['data']['type']
    assert_equal 'Fred Reader', json_response['data']['attributes']['name']

    # The test is hardcoded with the include order. This should be changed at some
    # point since either thing could come first and still be valid
    assert_equal '1001', json_response['included'][0]['id']
    assert_equal 'authors', json_response['included'][0]['type']
    assert_equal '2', json_response['included'][1]['id']
    assert_equal 'books', json_response['included'][1]['type']
  end

  def test_show_author_do_not_include_polymorphic_linkage
    assert_cacheable_get :show, params: { id: '1002', include: 'pictures' }
    assert_response :success
    assert_equal '1002', json_response['data']['id']
    assert_equal 'authors', json_response['data']['type']
    assert_equal 'Fred Reader', json_response['data']['attributes']['name']
    assert json_response['included'][0]['relationships']['imageable']['links']
    refute json_response['included'][0]['relationships']['imageable']['data']
  end

  def test_show_author_include_polymorphic_linkage
    JSONAPI.configuration.always_include_to_one_linkage_data = true

    assert_cacheable_get :show, params: { id: '1002', include: 'pictures' }
    assert_response :success
    assert_equal '1002', json_response['data']['id']
    assert_equal 'authors', json_response['data']['type']
    assert_equal 'Fred Reader', json_response['data']['attributes']['name']
    assert json_response['included'][0]['relationships']['imageable']['links']
    assert json_response['included'][0]['relationships']['imageable']['data']
    assert_equal 'products', json_response['included'][0]['relationships']['imageable']['data']['type']
    assert_equal '1', json_response['included'][0]['relationships']['imageable']['data']['id']
  ensure
    JSONAPI.configuration.always_include_to_one_linkage_data = false
  end
end

class Api::V2::AuthorsControllerTest < ActionController::TestCase
  def test_cache_pollution_for_non_admin_indirect_access_to_banned_books
    cache = ActiveSupport::Cache::MemoryStore.new
    with_resource_caching(cache) do
      $test_user = Person.find(1005)
      get :show, params: { id: '1002', include: 'books' }
      assert_response :success
      assert_equal 2, json_response['included'].length

      $test_user = Person.find(1001)
      get :show, params: { id: '1002', include: 'books' }
      assert_response :success
      assert_equal 1, json_response['included'].length
    end
  end
end

class Api::BoxesControllerTest < ActionController::TestCase
  def test_complex_includes_base
    assert_cacheable_get :index
    assert_response :success
  end

  def test_complex_includes_filters_nil_includes
    assert_cacheable_get :index, params: { include: ',,' }
    assert_response :success
  end

  def test_complex_includes_two_level
    assert_cacheable_get :index, params: { include: 'things,things.user' }

    assert_response :success

    # The test is hardcoded with the include order. This should be changed at some
    # point since either thing could come first and still be valid
    assert_equal '10', json_response['included'][0]['id']
    assert_equal 'things', json_response['included'][0]['type']
    assert_equal '10001',  json_response['included'][0]['relationships']['user']['data']['id']
    assert_nil json_response['included'][0]['relationships']['things']['data']

    assert_equal '20', json_response['included'][1]['id']
    assert_equal 'things', json_response['included'][1]['type']
    assert_equal '10001', json_response['included'][1]['relationships']['user']['data']['id']
    assert_nil json_response['included'][1]['relationships']['things']['data']
  end

  def test_complex_includes_things_nested_things
    assert_cacheable_get :index, params: { include: 'things,things.things,things.things.things' }

    assert_response :success
    assert_hash_equals(
      {
        "data" => [
          {
            "id" => "100",
            "type" => "boxes",
            "links" => {
              "self" => "http://test.host/api/boxes/100"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/boxes/100/relationships/things",
                  "related" => "http://test.host/api/boxes/100/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "10"
                  },
                  {
                    "type" => "things",
                    "id" => "20"
                  }
                ]
              }
            }
          },
          {
            "id" => "102",
            "type" => "boxes",
            "links" => {
              "self" => "http://test.host/api/boxes/102"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/boxes/102/relationships/things",
                  "related" => "http://test.host/api/boxes/102/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "30"
                  }
                ]
              }
            }
          }
        ],
        "included" => [
          {
            "id" => "10",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/10"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/box",
                  "related" => "http://test.host/api/things/10/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "100"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/user",
                  "related" => "http://test.host/api/things/10/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/things",
                  "related" => "http://test.host/api/things/10/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "20"
                  }
                ]
              }
            }
          },
          {
            "id" => "20",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/20"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/box",
                  "related" => "http://test.host/api/things/20/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "100"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/user",
                  "related" => "http://test.host/api/things/20/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/things",
                  "related" => "http://test.host/api/things/20/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "10"
                  }
                ]
              }
            }
          },
          {
            "id" => "30",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/30"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/box",
                  "related" => "http://test.host/api/things/30/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "102"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/user",
                  "related" => "http://test.host/api/things/30/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/things",
                  "related" => "http://test.host/api/things/30/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "40"
                  },
                  {
                    "type" => "things",
                    "id" => "50"
                  }

                ]
              }
            }
          },
          {
            "id" => "40",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/40"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/box",
                  "related" => "http://test.host/api/things/40/box"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/user",
                  "related" => "http://test.host/api/things/40/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/things",
                  "related" => "http://test.host/api/things/40/things"
                },
                "data" => []
              }
            }
          },
          {
            "id" => "50",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/50"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/box",
                  "related" => "http://test.host/api/things/50/box"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/user",
                  "related" => "http://test.host/api/things/50/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/things",
                  "related" => "http://test.host/api/things/50/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "60"
                  }
                ]
              }
            }
          },
          {
            "id" => "60",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/60"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/60/relationships/box",
                  "related" => "http://test.host/api/things/60/box"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/60/relationships/user",
                  "related" => "http://test.host/api/things/60/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/60/relationships/things",
                  "related" => "http://test.host/api/things/60/things"
                }
              }
            }
          }
        ]
      },
      json_response
    )
  end

  def test_complex_includes_nested_things_secondary_users
    assert_cacheable_get :index, params: { include: 'things,things.user,things.things' }

    assert_response :success
    assert_hash_equals(
      {
        "data" => [
          {
            "id" => "100",
            "type" => "boxes",
            "links" => {
              "self" => "http://test.host/api/boxes/100"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/boxes/100/relationships/things",
                  "related" => "http://test.host/api/boxes/100/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "10"
                  },
                  {
                    "type" => "things",
                    "id" => "20"
                  }
                ]
              }
            }
          },
          {
            "id" => "102",
            "type" => "boxes",
            "links" => {
              "self" => "http://test.host/api/boxes/102"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/boxes/102/relationships/things",
                  "related" => "http://test.host/api/boxes/102/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "30"
                  }
                ]
              }
            }
          }
        ],
        "included" => [
          {
            "id" => "10",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/10"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/box",
                  "related" => "http://test.host/api/things/10/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "100"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/user",
                  "related" => "http://test.host/api/things/10/user"
                },
                "data" => {
                  "type" => "users",
                  "id" => "10001"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/10/relationships/things",
                  "related" => "http://test.host/api/things/10/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "20"
                  }
                ]
              }
            }
          },
          {
            "id" => "20",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/20"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/box",
                  "related" => "http://test.host/api/things/20/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "100"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/user",
                  "related" => "http://test.host/api/things/20/user"
                },
                "data" => {
                  "type" => "users",
                  "id" => "10001"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/20/relationships/things",
                  "related" => "http://test.host/api/things/20/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "10"
                  }
                ]
              }
            }
          },
          {
            "id" => "30",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/30"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/box",
                  "related" => "http://test.host/api/things/30/box"
                },
                "data" => {
                  "type" => "boxes",
                  "id" => "102"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/user",
                  "related" => "http://test.host/api/things/30/user"
                },
                "data" => {
                  "type" => "users",
                  "id" => "10002"
                }

              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/30/relationships/things",
                  "related" => "http://test.host/api/things/30/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "40"
                  },
                  {
                    "type" => "things",
                    "id" => "50"
                  }

                ]
              }
            }
          },
          {
            "id" => "40",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/40"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/box",
                  "related" => "http://test.host/api/things/40/box"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/user",
                  "related" => "http://test.host/api/things/40/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/40/relationships/things",
                  "related" => "http://test.host/api/things/40/things"
                }
              }
            }
          },
          {
            "id" => "50",
            "type" => "things",
            "links" => {
              "self" => "http://test.host/api/things/50"
            },
            "relationships" => {
              "box" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/box",
                  "related" => "http://test.host/api/things/50/box"
                }
              },
              "user" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/user",
                  "related" => "http://test.host/api/things/50/user"
                }
              },
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/things/50/relationships/things",
                  "related" => "http://test.host/api/things/50/things"
                }
              }
            }
          },
          {
            "id" => "10001",
            "type" => "users",
            "links" => {
              "self" => "http://test.host/api/users/10001"
            },
            "attributes" => {
              "name" => "user 1"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/users/10001/relationships/things",
                  "related" => "http://test.host/api/users/10001/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "10"
                  },
                  {
                    "type" => "things",
                    "id" => "20"
                  }
                ]
              }
            }
          },
          {
            "id" => "10002",
            "type" => "users",
            "links" => {
              "self" => "http://test.host/api/users/10002"
            },
            "attributes" => {
              "name" => "user 2"
            },
            "relationships" => {
              "things" => {
                "links" => {
                  "self" => "http://test.host/api/users/10002/relationships/things",
                  "related" => "http://test.host/api/users/10002/things"
                },
                "data" => [
                  {
                    "type" => "things",
                    "id" => "30"
                  }
                ]
              }
            }
          }
        ]
      },
      json_response
    )
  end
end

class BlogPostsControllerTest < ActionController::TestCase
  def test_filter_by_delegated_attribute
    assert_cacheable_get :index, params: { filter: { name: 'some title' } }
    assert_response :success
  end

  def test_sorting_by_delegated_attribute
    assert_cacheable_get :index, params: { sort: 'name' }
    assert_response :success
  end

  def test_fields_with_delegated_attribute
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key

    assert_cacheable_get :index, params: { fields: { blog_posts: 'name' } }
    assert_response :success
    assert_equal ['name'], json_response['data'].first['attributes'].keys
  ensure
    JSONAPI.configuration = original_config
  end
end

class RobotsControllerTest < ActionController::TestCase
  def teardown
    Robot.delete_all
  end

  def test_fetch_robots_with_sort_by_name
    Robot.create! name: 'John', version: 1
    Robot.create! name: 'jane', version: 1
    assert_cacheable_get :index, params: { sort: 'name' }
    assert_response :success

    if ENV['DATABASE_URL'].starts_with?('postgres')
      assert_equal 'jane', json_response['data'].first['attributes']['name']
    else
      assert_equal 'John', json_response['data'].first['attributes']['name']
    end
  end

  def test_fetch_robots_with_sort_by_lower_name
    Robot.create! name: 'John', version: 1
    Robot.create! name: 'jane', version: 1
    assert_cacheable_get :index, params: { sort: 'lower_name' }
    assert_response :success
    assert_equal 'jane', json_response['data'].first['attributes']['name']
  end

  def test_fetch_robots_with_sort_by_version
    Robot.create! name: 'John', version: 1
    Robot.create! name: 'jane', version: 2
    assert_cacheable_get :index, params: { sort: 'version' }
    assert_response 400
    assert_equal 'version is not a valid sort criteria for robots', json_response['errors'].first['detail']
  end
end

class Api::V6::AuthorDetailsControllerTest < ActionController::TestCase
  def after_teardown
    Api::V6::AuthorDetailResource.paginator :none # TODO: ???
  end

  def test_that_the_last_two_author_details_belong_to_an_author
    Api::V6::AuthorDetailResource.paginator :offset

    total_count = AuthorDetail.count
    assert_operator total_count, :>=, 2

    assert_cacheable_get :index, params: { sort: :id, include: :author, page: { limit: 10, offset: total_count - 2 } }
    assert_response :success
    assert_equal 2, json_response['data'].size
    assert_not_nil json_response['data'][0]['relationships']['author']['data']
    assert_not_nil json_response['data'][1]['relationships']['author']['data']
  end

  def test_that_the_last_author_detail_includes_its_author_even_if_returned_as_the_single_entry_on_a_page_with_nonzero_offset
    Api::V6::AuthorDetailResource.paginator :offset

    total_count = AuthorDetail.count
    assert_operator total_count, :>=, 2

    assert_cacheable_get :index, params: { sort: :id, include: :author, page: { limit: 10, offset: total_count - 1 } }
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_not_nil json_response['data'][0]['relationships']['author']['data']
  end
end
