require File.expand_path('../../test_helper', __FILE__)

def set_content_type_header!
  @request.headers['Content-Type'] = 'application/vnd.api+json'
end

class PostsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
  end

  def test_index
    assert_cacheable_get :index
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
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.", json_response['errors'][0]['detail']
  end

  def test_accept_header_jsonapi_multiple_modified
    @request.headers['Accept'] =
      "#{JSONAPI::MEDIA_TYPE};charset=test,#{JSONAPI::MEDIA_TYPE};charset=test"

    assert_cacheable_get :index
    assert_response 406
    assert_equal 'Not acceptable', json_response['errors'][0]['title']
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.", json_response['errors'][0]['detail']
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
    assert_equal "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{@request.headers['Accept']}'.", json_response['errors'][0]['detail']
  end

  def test_exception_class_whitelist
    original_whitelist = JSONAPI.configuration.exception_class_whitelist.dup
    $PostProcessorRaisesErrors = true
    # test that the operations dispatcher rescues the error when it
    # has not been added to the exception_class_whitelist
    assert_cacheable_get :index
    assert_response 500

    # test that the operations dispatcher does not rescue the error when it
    # has been added to the exception_class_whitelist
    JSONAPI.configuration.exception_class_whitelist << PostsController::SpecialError
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.exception_class_whitelist = original_whitelist
  end

  def test_whitelist_all_exceptions
    original_config = JSONAPI.configuration.whitelist_all_exceptions
    $PostProcessorRaisesErrors = true
    assert_cacheable_get :index
    assert_response 500

    JSONAPI.configuration.whitelist_all_exceptions = true
    assert_cacheable_get :index
    assert_response 403
  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.whitelist_all_exceptions = original_config
  end

  def test_exception_includes_backtrace_when_enabled
    original_config = JSONAPI.configuration.include_backtraces_in_errors
    $PostProcessorRaisesErrors = true

    JSONAPI.configuration.include_backtraces_in_errors = true
    assert_cacheable_get :index
    assert_response 500
    assert_includes @response.body, "backtrace", "expected backtrace in error body"

    JSONAPI.configuration.include_backtraces_in_errors = false
    assert_cacheable_get :index
    assert_response 500
    refute_includes @response.body, "backtrace", "expected backtrace in error body"

  ensure
    $PostProcessorRaisesErrors = false
    JSONAPI.configuration.include_backtraces_in_errors = original_config
  end

  def test_on_server_error_block_callback_with_exception
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_whitelist = []
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
    JSONAPI.configuration.exception_class_whitelist = []
    $PostProcessorRaisesErrors = true

    #ignores methods that don't exist
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
    JSONAPI.configuration.exception_class_whitelist = []
    $PostSerializerRaisesErrors = true

    #ignores methods that don't exist
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

  def test_index_filter_with_empty_result
    assert_cacheable_get :index, params: {filter: {title: 'post that does not exist'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 0, json_response['data'].size
  end

  def test_index_filter_by_id
    assert_cacheable_get :index, params: {filter: {id: '1'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_title
    assert_cacheable_get :index, params: {filter: {title: 'New post'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_with_hash_values
    assert_cacheable_get :index, params: {filter: {search: {title: 'New post'}}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].size
  end

  def test_index_filter_by_ids
    assert_cacheable_get :index, params: {filter: {ids: '1,2'}}
    assert_response :success
    assert json_response['data'].is_a?(Array)
    assert_equal 2, json_response['data'].size
  end

  def test_index_filter_by_ids_and_include_related
    assert_cacheable_get :index, params: {filter: {id: '2'}, include: 'comments'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_by_ids_and_include_related_different_type
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, include: 'author'}
    assert_response :success
    assert_equal 2, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end

  def test_index_filter_not_allowed
    JSONAPI.configuration.allow_filter = false
    assert_cacheable_get :index, params: {filter: {id: '1'}}
    assert_response :bad_request
  ensure
    JSONAPI.configuration.allow_filter = true
  end

  def test_include_belongs_to_exists
    assert_cacheable_get :index, params: {filter: {id: '2'}, include: 'section'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '2', json_response['data'][0]['relationships']['section']['data']['id']
    assert_equal 1, json_response['included'].size
  end

  def test_include_belongs_to_nonexistent
    assert_cacheable_get :index, params: {filter: {id: '1'}, include: 'section'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_nil json_response['data'][0]['relationships']['section']['data']
    assert_nil json_response['included']
  end

  def test_index_include_one_level_query_count
    assert_query_count(2) do
      assert_cacheable_get :index, params: {include: 'author'}
    end
    assert_response :success
  end

  def test_index_include_two_levels_query_count
    assert_query_count(3) do
      assert_cacheable_get :index, params: {include: 'author,author.comments'}
    end
    assert_response :success
  end

  def test_index_filter_by_ids_and_fields
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, fields: {posts: 'id,title,author'}}
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
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, 'fields' => {'posts' => 'id,title,author'}}
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
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, 'fields' => {'currencies' => 'code'}}
    assert_response :bad_request
    assert_match /currencies is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_by_ids_and_fields_2
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, fields: {posts: 'author'}}
    assert_response :success
    assert_equal 2, json_response['data'].size

    # type, id, links, relationships
    assert_equal 4, json_response['data'][0].size
    assert json_response['data'][0].key?('type')
    assert json_response['data'][0].key?('id')
    assert json_response['data'][0]['relationships'].key?('author')
  end

  def test_filter_relationship_single
    assert_query_count(1) do
      assert_cacheable_get :index, params: {filter: {tags: '5,1'}}
    end
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_match /New post/, response.body
    assert_match /JR Solves your serialization woes!/, response.body
    assert_match /JR How To/, response.body
  end

  def test_filter_relationships_multiple
    assert_query_count(1) do
      assert_cacheable_get :index, params: {filter: {tags: '5,1', comments: '3'}}
    end
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_match /JR Solves your serialization woes!/, response.body
  end

  def test_filter_relationships_multiple_not_found
    assert_cacheable_get :index, params: {filter: {tags: '1', comments: '3'}}
    assert_response :success
    assert_equal 0, json_response['data'].size
  end

  def test_bad_filter
    assert_cacheable_get :index, params: {filter: {post_ids: '1,2'}}
    assert_response :bad_request
    assert_match /post_ids is not allowed/, response.body
  end

  def test_bad_filter_value_not_integer_array
    assert_cacheable_get :index, params: {filter: {id: 'asdfg'}}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_integer
    assert_cacheable_get :index, params: {filter: {id: 'asdfg'}}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_bad_filter_value_not_found_array
    assert_cacheable_get :index, params: {filter: {id: '5412333'}}
    assert_response :not_found
    assert_match /5412333 could not be found/, response.body
  end

  def test_bad_filter_value_not_found
    assert_cacheable_get :index, params: {filter: {id: '5412333'}}
    assert_response :not_found
    assert_match /5412333 could not be found/, json_response['errors'][0]['detail']
  end

  def test_field_not_supported
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, 'fields' => {'posts' => 'id,title,rank,author'}}
    assert_response :bad_request
    assert_match /rank is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_resource_not_supported
    assert_cacheable_get :index, params: {filter: {id: '1,2'}, 'fields' => {'posters' => 'id,title'}}
    assert_response :bad_request
    assert_match /posters is not a valid resource./, json_response['errors'][0]['detail']
  end

  def test_index_filter_on_relationship
    assert_cacheable_get :index, params: {filter: {author: '1'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_blank
    assert_cacheable_get :index, params: {sort: ''}

    assert_response :success
  end

  def test_sorting_asc
    assert_cacheable_get :index, params: {sort: 'title'}

    assert_response :success
    assert_equal "A First Post", json_response['data'][0]['attributes']['title']
  end

  def test_sorting_desc
    assert_cacheable_get :index, params: {sort: '-title'}

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['attributes']['title']
  end

  def test_sorting_by_multiple_fields
    assert_cacheable_get :index, params: {sort: 'title,body'}

    assert_response :success
    assert_equal '14', json_response['data'][0]['id']
  end

  def create_alphabetically_first_user_and_post
    author = Person.create(name: "Aardvark", date_joined: Time.now)
    author.posts.create(title: "My first post", body: "Hello World")
  end

  def test_sorting_by_relationship_field
    post  = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: {sort: 'author.name'}

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'
    assert_equal '17', json_response['data'][0]['id'], 'nil is at the top'
    assert_equal post.id.to_s, json_response['data'][1]['id'], 'alphabetically first user is second'
  end

  def test_desc_sorting_by_relationship_field
    post  = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: {sort: '-author.name'}

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'
    assert_equal '17', json_response['data'][-1]['id'], 'nil is at the bottom'
    assert_equal post.id.to_s, json_response['data'][-2]['id'], 'alphabetically first user is second last'
  end

  def test_sorting_by_relationship_field_include
    post  = create_alphabetically_first_user_and_post
    assert_cacheable_get :index, params: {include: 'author', sort: 'author.name'}

    assert_response :success
    assert json_response['data'].length > 10, 'there are enough records to show sort'
    assert_equal '17', json_response['data'][0]['id'], 'nil is at the top'
    assert_equal post.id.to_s, json_response['data'][1]['id'], 'alphabetically first user is second'
  end

  def test_invalid_sort_param
    assert_cacheable_get :index, params: {sort: 'asdfg'}

    assert_response :bad_request
    assert_match /asdfg is not a valid sort criteria for post/, response.body
  end

  def test_show_single_with_sort_disallowed
    JSONAPI.configuration.allow_sort = false
    assert_cacheable_get :index, params: {sort: 'title,body'}
    assert_response :bad_request
  ensure
    JSONAPI.configuration.allow_sort = true
  end

  def test_excluded_sort_param
    assert_cacheable_get :index, params: {sort: 'id'}

    assert_response :bad_request
    assert_match /id is not a valid sort criteria for post/, response.body
  end

  def test_show_single
    assert_cacheable_get :show, params: {id: '1'}
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

  def test_show_single_with_includes
    assert_cacheable_get :show, params: {id: '1', include: 'comments'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['attributes']['title']
    assert_equal 'A body!!!', json_response['data']['attributes']['body']
    assert_nil json_response['data']['relationships']['tags']['data']
    assert matches_array?([{'type' => 'comments', 'id' => '1'}, {'type' => 'comments', 'id' => '2'}],
                          json_response['data']['relationships']['comments']['data'])
    assert_equal 2, json_response['included'].size
  end

  def test_show_with_filtered_includes_when_not_eager_loaded
    # tags are not eagerly loaded on a post but may still be filtered
    get :show, params: { id: '1', include: 'tags', filter: { 'tags.name' => ['whiny'] } }
    assert_response :success
    assert_equal 1, json_response['included'].size
  end

  def test_show_with_filtered_includes_when_not_eager_loaded_and_all_filtered_out
    get :show, params: { id: '1', include: 'tags', filter: { 'tags.name' => ['no-tag-with-this-name'] } }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'New post', json_response['data']['attributes']['title']
    assert_equal 'A body!!!', json_response['data']['attributes']['body']
    assert_nil json_response['included']
  end

  def test_show_single_with_include_disallowed
    JSONAPI.configuration.allow_include = false
    assert_cacheable_get :show, params: {id: '1', include: 'comments'}
    assert_response :bad_request
  ensure
    JSONAPI.configuration.allow_include = true
  end

  def test_show_single_with_fields
    assert_cacheable_get :show, params: {id: '1', fields: {posts: 'author'}}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_nil json_response['data']['attributes']
  end

  def test_show_single_with_fields_string
    assert_cacheable_get :show, params: {id: '1', fields: 'author'}
    assert_response :bad_request
    assert_match /Fields must specify a type./, json_response['errors'][0]['detail']
  end

  def test_show_single_invalid_id_format
    assert_cacheable_get :show, params: {id: 'asdfg'}
    assert_response :bad_request
    assert_match /asdfg is not a valid value for id/, response.body
  end

  def test_show_single_missing_record
    assert_cacheable_get :show, params: {id: '5412333'}
    assert_response :not_found
    assert_match /record identified by 5412333 could not be found/, response.body
  end

  def test_show_malformed_fields_not_list
    assert_cacheable_get :show, params: {id: '1', 'fields' => ''}
    assert_response :bad_request
    assert_match /Fields must specify a type./, json_response['errors'][0]['detail']
  end

  def test_show_malformed_fields_type_not_list
    assert_cacheable_get :show, params: {id: '1', 'fields' => {'posts' => ''}}
    assert_response :bad_request
    assert_match /nil is not a valid field for posts./, json_response['errors'][0]['detail']
  end

  def test_create_simple
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'JR is Great', json_response['data']['attributes']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['attributes']['body']
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
    assert_equal json_response['data']['links']['self'], response.location
  end

  def test_create_simple_id_not_allowed
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          id: 'asdfg',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /id is not allowed/, response.body
    assert_nil response.location
  end

  def test_create_link_to_missing_object
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '304567'}}
          }
        }
      }

    assert_response :unprocessable_entity
    # TODO: check if this validation is working
    assert_match /author - can't be blank/, response.body
    assert_nil response.location
  end

  def test_create_extra_param
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            asdfg: 'aaaa',
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
    assert_nil response.location
  end

  def test_create_extra_param_allow_extra_params
    JSONAPI.configuration.raise_if_parameters_not_allowed = false

    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          id: 'my_id',
          attributes: {
            asdfg: 'aaaa',
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        },
        include: 'author'
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal 'JR is Great', json_response['data']['attributes']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['attributes']['body']

    assert_equal 2, json_response['meta']["warnings"].count
    assert_equal "Param not allowed", json_response['meta']["warnings"][0]["title"]
    assert_equal "id is not allowed.", json_response['meta']["warnings"][0]["detail"]
    assert_equal '105', json_response['meta']["warnings"][0]["code"]
    assert_equal "Param not allowed", json_response['meta']["warnings"][1]["title"]
    assert_equal "asdfg is not allowed.", json_response['meta']["warnings"][1]["detail"]
    assert_equal '105', json_response['meta']["warnings"][1]["code"]
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
  ensure
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
  end

  def test_create_with_invalid_data
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JSONAPIResources is the greatest thing...',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: nil
          }
        }
      }

    assert_response :unprocessable_entity

    assert_equal "/data/relationships/author", json_response['errors'][0]['source']['pointer']
    assert_equal "can't be blank", json_response['errors'][0]['title']
    assert_equal "author - can't be blank", json_response['errors'][0]['detail']

    assert_equal "/data/attributes/title", json_response['errors'][1]['source']['pointer']
    assert_equal "is too long (maximum is 35 characters)", json_response['errors'][1]['title']
    assert_equal "title - is too long (maximum is 35 characters)", json_response['errors'][1]['detail']
    assert_nil response.location
  end

  def test_create_multiple
    set_content_type_header!
    post :create, params:
      {
        data: [
          {
            type: 'posts',
            attributes: {
              title: 'JR is Great',
              body: 'JSONAPIResources is the greatest thing since unsliced bread.'
            },
            relationships: {
              author: {data: {type: 'people', id: '3'}}
            }
          },
          {
            type: 'posts',
            attributes: {
              title: 'Ember is Great',
              body: 'Ember is the greatest thing since unsliced bread.'
            },
            relationships: {
              author: {data: {type: 'people', id: '3'}}
            }
          }
        ]
      }

    assert_response :bad_request
    assert_match /Invalid data format/, response.body
  end

  def test_create_simple_missing_posts
    set_content_type_header!
    post :create, params:
      {
        data_spelled_wrong: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, json_response['errors'][0]['detail']
    assert_nil response.location
  end

  def test_create_simple_wrong_type
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts_spelled_wrong',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /posts_spelled_wrong is not a valid resource./, json_response['errors'][0]['detail']
    assert_nil response.location
  end

  def test_create_simple_missing_type
    set_content_type_header!
    post :create, params:
      {
        data: {
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /The required parameter, type, is missing./, json_response['errors'][0]['detail']
    assert_nil response.location
  end

  def test_create_simple_unpermitted_attributes
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            subject: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /subject/, json_response['errors'][0]['detail']
    assert_nil response.location
  end

  def test_create_simple_unpermitted_attributes_allow_extra_params
    JSONAPI.configuration.raise_if_parameters_not_allowed = false

    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            subject: 'JR is SUPER Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}}
          }
        },
        include: 'author'
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal 'JR is Great', json_response['data']['attributes']['title']
    assert_equal 'JR is Great', json_response['data']['attributes']['subject']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['attributes']['body']


    assert_equal 1, json_response['meta']["warnings"].count
    assert_equal "Param not allowed", json_response['meta']["warnings"][0]["title"]
    assert_equal "subject is not allowed.", json_response['meta']["warnings"][0]["detail"]
    assert_equal '105', json_response['meta']["warnings"][0]["code"]
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
  ensure
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
  end

  def test_create_with_links_to_many_type_ids
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'author'
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal 'JR is Great', json_response['data']['attributes']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['attributes']['body']
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
  end

  def test_create_with_links_to_many_array
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great',
            body: 'JSONAPIResources is the greatest thing since unsliced bread.'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'author'
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal 'JR is Great', json_response['data']['attributes']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread.', json_response['data']['attributes']['body']
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
  end

  def test_create_with_links_include_and_fields
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR is Great!',
            body: 'JSONAPIResources is the greatest thing since unsliced bread!'
          },
          relationships: {
            author: {data: {type: 'people', id: '3'}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'author,author.posts',
        fields: {posts: 'id,title,author'}
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal 'JR is Great!', json_response['data']['attributes']['title']
    assert_not_nil json_response['included'].size
    assert_equal "http://test.host/posts/#{json_response['data']['id']}", json_response['data']['links']['self']
  end

  def test_update_with_links
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'posts',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {data: {type: 'sections', id: "#{javascript.id}"}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'tags,author,section'
      }

    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal javascript.id.to_s, json_response['data']['relationships']['section']['data']['id']
    assert_equal 'A great new Post', json_response['data']['attributes']['title']
    assert_equal 'AAAA', json_response['data']['attributes']['body']
    assert matches_array?([{'type' => 'tags', 'id' => '3'}, {'type' => 'tags', 'id' => '4'}],
                          json_response['data']['relationships']['tags']['data'])
  end

  def test_update_with_internal_server_error
    set_content_type_header!
    post_object = Post.find(3)
    title = post_object.title

    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'posts',
          attributes: {
            title: 'BOOM'
          }
        }
      }

    assert_response 500
    post_object = Post.find(3)
    assert_equal title, post_object.title
  end

  def test_update_with_links_allow_extra_params
    JSONAPI.configuration.raise_if_parameters_not_allowed = false

    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'posts',
          attributes: {
            title: 'A great new Post',
            subject: 'A great new Post',
          },
          relationships: {
            section: {data: {type: 'sections', id: "#{javascript.id}"}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'tags,author,section'
      }

    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_equal javascript.id.to_s, json_response['data']['relationships']['section']['data']['id']
    assert_equal 'A great new Post', json_response['data']['attributes']['title']
    assert_equal 'AAAA', json_response['data']['attributes']['body']
    assert matches_array?([{'type' => 'tags', 'id' => '3'}, {'type' => 'tags', 'id' => '4'}],
                          json_response['data']['relationships']['tags']['data'])


    assert_equal 1, json_response['meta']["warnings"].count
    assert_equal "Param not allowed", json_response['meta']["warnings"][0]["title"]
    assert_equal "subject is not allowed.", json_response['meta']["warnings"][0]["detail"]
    assert_equal '105', json_response['meta']["warnings"][0]["code"]
  ensure
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
  end

  def test_update_remove_links
    orig_controller = @controller.dup

    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'posts',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {data: {type: 'sections', id: 1}},
            tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
          }
        },
        include: 'tags'
      }

    assert_response :success

    # FIXME Resetting the controller because ActionController::TestCase only allows you
    # to test a single controller action per test method; really, this test should be in
    # an Integration Test instead.
    @controller = orig_controller
    setup_controller_request_and_response
    set_content_type_header!

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 3,
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: nil,
            tags: []
          }
        },
        include: 'tags,author,section'
      }

    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['author']['data']['id']
    assert_nil json_response['data']['relationships']['section']['data']
    assert_equal 'A great new Post', json_response['data']['attributes']['title']
    assert_equal 'AAAA', json_response['data']['attributes']['body']
    assert matches_array?([],
                          json_response['data']['relationships']['tags']['data'])
  end

  def test_update_relationship_to_one
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(4)
    assert_not_equal ruby.id, post_object.section_id

    put :update_relationship, params: {post_id: 4, relationship: 'section', data: {type: 'sections', id: "#{ruby.id}"}}

    assert_response :no_content
    post_object = Post.find(4)
    assert_equal ruby.id, post_object.section_id
  end

  def test_update_relationship_to_one_nil
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(4)
    assert_not_equal ruby.id, post_object.section_id

    put :update_relationship, params: {post_id: 4, relationship: 'section', data: nil}

    assert_response :no_content
    post_object = Post.find(4)
    assert_nil post_object.section_id
  end

  def test_update_relationship_to_one_invalid_links_hash_keys_ids
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'section', data: {type: 'sections', ids: 'foo'}}

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_to_one_invalid_links_hash_count
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'section', data: {type: 'sections'}}

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_to_many_not_array
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: {type: 'tags', id: 2}}

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_to_one_invalid_links_hash_keys_type_mismatch
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'section', data: {type: 'comment', id: '3'}}

    assert_response :bad_request
    assert_match /Type Mismatch/, response.body
  end

  def test_update_nil_to_many_links
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 3,
          relationships: {
            tags: nil
          }
        }
      }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_bad_hash_to_many_links
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 3,
          relationships: {
            tags: {data: {typ: 'bad link', idd: 'as'}}
          }
        }
      }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_other_to_many_links
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 3,
          relationships: {
            tags: 'bad link'
          }
        }
      }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_other_to_many_links_data_nil
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 3,
          relationships: {
            tags: {data: nil}
          }
        }
      }

    assert_response :bad_request
    assert_match /Invalid Links Object/, response.body
  end

  def test_update_relationship_to_one_singular_param_id_nil
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section = ruby
    post_object.save!

    put :update_relationship, params: {post_id: 3, relationship: 'section', data: {type: 'sections', id: nil}}

    assert_response :no_content
    assert_nil post_object.reload.section_id
  end

  def test_update_relationship_to_one_data_nil
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section = ruby
    post_object.save!

    put :update_relationship, params: {post_id: 3, relationship: 'section', data: nil}

    assert_response :no_content
    assert_nil post_object.reload.section_id
  end

  def test_remove_relationship_to_one
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = ruby.id
    post_object.save!

    put :destroy_relationship, params: {post_id: 3, relationship: 'section'}

    assert_response :no_content
    post_object = Post.find(3)
    assert_nil post_object.section_id
  end

  def test_update_relationship_to_one_singular_param
    set_content_type_header!
    ruby = Section.find_by(name: 'ruby')
    post_object = Post.find(3)
    post_object.section_id = nil
    post_object.save!

    put :update_relationship, params: {post_id: 3, relationship: 'section', data: {type: 'sections', id: "#{ruby.id}"}}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal ruby.id, post_object.section_id
  end

  def test_remove_relationship_to_many_belongs_to
    set_content_type_header!
    c = Comment.find(3)
    p = Post.find(2)
    total_comment_count = Comment.count
    post_comment_count = p.comments.count

    put :destroy_relationship, params: {post_id: "#{p.id}", relationship: 'comments', data: [{type: 'comments', id: "#{c.id}"}]}

    assert_response :no_content
    p = Post.find(2)
    c = Comment.find(3)

    assert_equal post_comment_count - 1, p.comments.length
    assert_equal total_comment_count, Comment.count

    assert_nil c.post_id
  end

  def test_update_relationship_to_many_join_table_single
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: []}
    assert_response :no_content

    post_object = Post.find(3)
    assert_equal 0, post_object.tags.length

    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 2}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 1, post_object.tags.length

    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 5}]}

    assert_response :no_content
    post_object = Post.find(3)
    tags = post_object.tags.collect { |tag| tag.id }
    assert_equal 1, tags.length
    assert matches_array? [5], tags
  end

  def test_update_relationship_to_many
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_to_many_join_table
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 5}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 3, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3, 5], post_object.tags.collect { |tag| tag.id }
  end

  def test_create_relationship_to_many_join_table_reflect
    JSONAPI.configuration.use_relationship_reflection = true
    set_content_type_header!
    post_object = Post.find(15)
    assert_equal 5, post_object.tags.collect { |tag| tag.id }.length

    put :update_relationship, params: {post_id: 15, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}, {type: 'tags', id: 4}]}

    assert_response :no_content
    post_object = Post.find(15)
    assert_equal 3, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3, 4], post_object.tags.collect { |tag| tag.id }
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_create_relationship_to_many_mismatched_type
    set_content_type_header!
    post :create_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'comments', id: 5}]}

    assert_response :bad_request
    assert_match /Type Mismatch/, response.body
  end

  def test_create_relationship_to_many_missing_id
    set_content_type_header!
    post :create_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', idd: 5}]}

    assert_response :bad_request
    assert_match /Data is not a valid Links Object./, response.body
  end

  def test_create_relationship_to_many_not_array
    set_content_type_header!
    post :create_relationship, params: {post_id: 3, relationship: 'tags', data: {type: 'tags', id: 5}}

    assert_response :bad_request
    assert_match /Data is not a valid Links Object./, response.body
  end

  def test_create_relationship_to_many_missing_data
    set_content_type_header!
    post :create_relationship, params: {post_id: 3, relationship: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_create_relationship_to_many_join_table_no_reflection
    JSONAPI.configuration.use_relationship_reflection = false
    set_content_type_header!
    p = Post.find(4)
    assert_equal [], p.tag_ids

    post :create_relationship, params: {post_id: 4, relationship: 'tags', data: [{type: 'tags', id: 1}, {type: 'tags', id: 2}, {type: 'tags', id: 3}]}
    assert_response :no_content

    p.reload
    assert_equal [1,2,3], p.tag_ids
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_create_relationship_to_many_join_table_reflection
    JSONAPI.configuration.use_relationship_reflection = true
    set_content_type_header!
    p = Post.find(4)
    assert_equal [], p.tag_ids

    post :create_relationship, params: {post_id: 4, relationship: 'tags', data: [{type: 'tags', id: 1}, {type: 'tags', id: 2}, {type: 'tags', id: 3}]}
    assert_response :no_content

    p.reload
    assert_equal [1,2,3], p.tag_ids
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_create_relationship_to_many_no_reflection
    JSONAPI.configuration.use_relationship_reflection = false
    set_content_type_header!
    p = Post.find(4)
    assert_equal [], p.comment_ids

    post :create_relationship, params: {post_id: 4, relationship: 'comments', data: [{type: 'comments', id: 7}, {type: 'comments', id: 8}]}

    assert_response :no_content
    p.reload
    assert_equal [7,8], p.comment_ids
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_create_relationship_to_many_reflection
    JSONAPI.configuration.use_relationship_reflection = true
    set_content_type_header!
    p = Post.find(4)
    assert_equal [], p.comment_ids

    post :create_relationship, params: {post_id: 4, relationship: 'comments', data: [{type: 'comments', id: 7}, {type: 'comments', id: 8}]}

    assert_response :no_content
    p.reload
    assert_equal [7,8], p.comment_ids
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_create_relationship_to_many_join_table_record_exists
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}

    assert_response :no_content
    post_object = Post.find(3)
    assert_equal 2, post_object.tags.collect { |tag| tag.id }.length
    assert matches_array? [2, 3], post_object.tags.collect { |tag| tag.id }

    post :create_relationship, params: {post_id: 3, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 5}]}

    assert_response :bad_request
    assert_match /The relation to 2 already exists./, response.body
  end

  def test_update_relationship_to_many_missing_tags
    set_content_type_header!
    put :update_relationship, params: {post_id: 3, relationship: 'tags'}

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_delete_relationship_to_many
    set_content_type_header!
    put :update_relationship,
        params: {
            post_id: 14,
            relationship: 'tags',
            data: [
                {type: 'tags', id: 2},
                {type: 'tags', id: 3},
                {type: 'tags', id: 4}
            ]
        }

    assert_response :no_content
    p = Post.find(14)
    assert_equal [2, 3, 4], p.tag_ids

    delete :destroy_relationship,
           params: {
               post_id: 14,
               relationship: 'tags',
               data: [
                   {type: 'tags', id: 3},
                   {type: 'tags', id: 4}
               ]
           }

    p.reload
    assert_response :no_content
    assert_equal [2], p.tag_ids
  end

  def test_delete_relationship_to_many_with_relationship_url_not_matching_type
    set_content_type_header!
    # Reflection turned off since tags doesn't have the inverse relationship
    PostResource.has_many :special_tags, relation_name: :special_tags, class_name: "Tag", reflect: false
    post :create_relationship, params: {post_id: 14, relationship: 'special_tags', data: [{type: 'tags', id: 2}]}

    #check the relationship was created successfully
    assert_equal 1, Post.find(14).special_tags.count
    before_tags = Post.find(14).tags.count

    delete :destroy_relationship, params: {post_id: 14, relationship: 'special_tags', data: [{type: 'tags', id: 2}]}
    assert_equal 0, Post.find(14).special_tags.count, "Relationship that matches URL relationship not destroyed"

    #check that the tag association is not affected
    assert_equal Post.find(14).tags.count, before_tags
  ensure
    PostResource.instance_variable_get(:@_relationships).delete(:special_tags)
  end

  def test_delete_relationship_to_many_does_not_exist
    set_content_type_header!
    put :update_relationship, params: {post_id: 14, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}
    assert_response :no_content
    p = Post.find(14)
    assert_equal [2, 3], p.tag_ids

    delete :destroy_relationship, params: {post_id: 14, relationship: 'tags', data: [{type: 'tags', id: 4}]}

    p.reload
    assert_response :not_found
    assert_equal [2, 3], p.tag_ids
  end

  def test_delete_relationship_to_many_with_empty_data
    set_content_type_header!
    put :update_relationship, params: {post_id: 14, relationship: 'tags', data: [{type: 'tags', id: 2}, {type: 'tags', id: 3}]}
    assert_response :no_content
    p = Post.find(14)
    assert_equal [2, 3], p.tag_ids

    put :update_relationship, params: {post_id: 14, relationship: 'tags', data: [] }

    p.reload
    assert_response :no_content
    assert_equal [], p.tag_ids
  end

  def test_update_mismatch_single_key
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: 2,
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /The URL does not support the key 2/, response.body
  end

  def test_update_extra_param
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: '3',
          attributes: {
            asdfg: 'aaaa',
            title: 'A great new Post'
          },
          relationships: {
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_extra_param_in_links
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: '3',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            asdfg: 'aaaa',
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /asdfg is not allowed/, response.body
  end

  def test_update_extra_param_in_links_allow_extra_params
    JSONAPI.configuration.raise_if_parameters_not_allowed = false
    JSONAPI.configuration.use_text_errors = true

    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: '3',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            asdfg: 'aaaa'
          }
        }
      }

    assert_response :success
    assert_equal "A great new Post", json_response["data"]["attributes"]["title"]
    assert_equal "Param not allowed", json_response["meta"]["warnings"][0]["title"]
    assert_equal "asdfg is not allowed.", json_response["meta"]["warnings"][0]["detail"]
    assert_equal "PARAM_NOT_ALLOWED", json_response["meta"]["warnings"][0]["code"]
  ensure
    JSONAPI.configuration.raise_if_parameters_not_allowed = true
    JSONAPI.configuration.use_text_errors = false
  end

  def test_update_missing_param
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data_spelled_wrong: {
          type: 'posts',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /The required parameter, data, is missing./, response.body
  end

  def test_update_missing_key
    set_content_type_header!

    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          attributes: {
            title: 'A great new Post'
          }
        }
      }

    assert_response :bad_request
    assert_match /The resource object does not contain a key/, response.body
  end

  def test_update_missing_type
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type_spelled_wrong: 'posts',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /The required parameter, type, is missing./, response.body
  end

  def test_update_unknown_key
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'posts',
          body: 'asdfg',
          attributes: {
            title: 'A great new Post'
          },
          relationships: {
            section: {type: 'sections', id: "#{javascript.id}"},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /body is not allowed/, response.body
  end

  def test_update_multiple_ids
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params: {
        id: '3,16',
        data: {
            type: 'posts',
            id: 3,
            attributes: {
                title: 'A great new Post QWERTY'
            },
            relationships: {
                section: { data: { type: 'sections', id: "#{javascript.id}" } },
                tags: { data: [{ type: 'tags', id: 3 }, { type: 'tags', id: 4 }] }
            }
        },
        include: 'tags'
    }

    assert_response :bad_request
    assert_match /The URL does not support the key 3/, response.body
  end

  def test_update_multiple_array
    set_content_type_header!
    javascript = Section.find_by(name: 'javascript')

    put :update, params:
        {
            id: 3,
            data: [
                {
                    type: 'posts',
                    id: 3,
                    attributes: {
                        title: 'A great new Post QWERTY'
                    },
                    relationships: {
                        section: {data: {type: 'sections', id: "#{javascript.id}"}},
                        tags: {data: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]}
                    }
                }
            ],
            include: 'tags'
        }

    assert_response :bad_request
    assert_match /Invalid data format/, response.body
  end

  def test_update_unpermitted_attributes
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          id: '3',
          attributes: {
            subject: 'A great new Post'
          },
          relationships: {
            author: {type: 'people', id: '1'},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
    assert_match /subject is not allowed./, response.body
  end

  def test_update_bad_attributes
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          type: 'posts',
          attributes: {
            subject: 'A great new Post'
          },
          linked_objects: {
            author: {type: 'people', id: '1'},
            tags: [{type: 'tags', id: 3}, {type: 'tags', id: 4}]
          }
        }
      }

    assert_response :bad_request
  end

  def test_delete_with_validation_error
    post = Post.create!(title: "can't destroy me", author: Person.first)
    delete :destroy, params: { id: post.id }

    assert_equal "can't destroy me", json_response['errors'][0]['title']
    assert_response :unprocessable_entity
  end

  def test_delete_single
    initial_count = Post.count
    delete :destroy, params: {id: '4'}
    assert_response :no_content
    assert_equal initial_count - 1, Post.count
  end

  def test_delete_multiple
    initial_count = Post.count
    delete :destroy, params: {id: '5,6'}
    assert_response :bad_request
    assert_match /5,6 is not a valid value for id/, response.body
    assert_equal initial_count, Post.count
  end

  def test_show_to_one_relationship
    assert_cacheable_get :show_relationship, params: {post_id: '1', relationship: 'author'}
    assert_response :success
    assert_hash_equals json_response,
                       {data: {
                         type: 'people',
                         id: '1'
                       },
                        links: {
                          self: 'http://test.host/posts/1/relationships/author',
                          related: 'http://test.host/posts/1/author'
                        }
                       }
  end

  def test_show_to_many_relationship
    assert_cacheable_get :show_relationship, params: {post_id: '2', relationship: 'tags'}
    assert_response :success
    assert_hash_equals json_response,
                       {
                         data: [
                           {type: 'tags', id: '5'}
                         ],
                         links: {
                           self: 'http://test.host/posts/2/relationships/tags',
                           related: 'http://test.host/posts/2/tags'
                         }
                       }
  end

  def test_show_to_many_relationship_invalid_id
    assert_cacheable_get :show_relationship, params: {post_id: '2,1', relationship: 'tags'}
    assert_response :bad_request
    assert_match /2,1 is not a valid value for id/, response.body
  end

  def test_show_to_one_relationship_nil
    assert_cacheable_get :show_relationship, params: {post_id: '17', relationship: 'author'}
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

  def test_get_related_resources_sorted
    assert_cacheable_get :get_related_resources, params: {person_id: '1', relationship: 'posts', source:'people', sort: 'title' }
    assert_response :success
    assert_equal 'JR How To', json_response['data'][0]['attributes']['title']
    assert_equal 'New post', json_response['data'][2]['attributes']['title']
    assert_cacheable_get :get_related_resources, params: {person_id: '1', relationship: 'posts', source:'people', sort: '-title' }
    assert_response :success
    assert_equal 'New post', json_response['data'][0]['attributes']['title']
    assert_equal 'JR How To', json_response['data'][2]['attributes']['title']
  end

  def test_get_related_resources_default_sorted
    assert_cacheable_get :get_related_resources, params: {person_id: '1', relationship: 'posts', source:'people'}
    assert_response :success
    assert_equal 'New post', json_response['data'][0]['attributes']['title']
    assert_equal 'JR How To', json_response['data'][2]['attributes']['title']
  end
end

class TagsControllerTest < ActionController::TestCase
  def test_tags_index
    assert_cacheable_get :index, params: {filter: {id: '6,7,8,9'}, include: 'posts.tags,posts.author.posts'}
    assert_response :success
    assert_equal 4, json_response['data'].size
    assert_equal 3, json_response['included'].size
  end

  def test_tags_show_multiple
    assert_cacheable_get :show, params: {id: '6,7,8,9'}
    assert_response :bad_request
    assert_match /6,7,8,9 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_include
    assert_cacheable_get :show, params: {id: '6,7,8,9', include: 'posts.tags,posts.author.posts'}
    assert_response :bad_request
    assert_match /6,7,8,9 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids
    assert_cacheable_get :show, params: {id: '6,99,9,100'}
    assert_response :bad_request
    assert_match /6,99,9,100 is not a valid value for id/, response.body
  end

  def test_tags_show_multiple_with_nonexistent_ids_at_the_beginning
    assert_cacheable_get :show, params: {id: '99,9,100'}
    assert_response :bad_request
    assert_match /99,9,100 is not a valid value for id/, response.body
  end

  def test_nested_includes_sort
    assert_cacheable_get :index, params: {filter: {id: '6,7,8,9'},
                                          include: 'posts.tags,posts.author.posts',
                                          sort: 'name'}
    assert_response :success
    assert_equal 4, json_response['data'].size
    assert_equal 3, json_response['included'].size
  end
end

class PicturesControllerTest < ActionController::TestCase
  def test_pictures_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_pictures_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: {include: 'imageable'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 2, json_response['included'].size
  end
end

class DocumentsControllerTest < ActionController::TestCase
  def test_documents_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 1, json_response['data'].size
  end

  def test_documents_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: {include: 'pictures'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end
end

class PicturesControllerTest < ActionController::TestCase
  def test_pictures_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_pictures_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: {include: 'imageable'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 2, json_response['included'].size
  end
end

class DocumentsControllerTest < ActionController::TestCase
  def test_documents_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal 1, json_response['data'].size
  end

  def test_documents_index_with_polymorphic_include_one_level
    assert_cacheable_get :index, params: {include: 'pictures'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 1, json_response['included'].size
  end
end

class ExpenseEntriesControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_text_error
    JSONAPI.configuration.use_text_errors = true
    assert_cacheable_get :index, params: {sort: 'not_in_record'}
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
    assert_cacheable_get :show, params: {id: 1}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_expense_entries_show_include
    assert_cacheable_get :show, params: {id: 1, include: 'isoCurrency,employee'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_bad_include_missing_relationship
    assert_cacheable_get :show, params: {id: 1, include: 'isoCurrencies,employees'}
    assert_response :bad_request
    assert_match /isoCurrencies is not a valid relationship of expenseEntries/, json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_bad_include_missing_sub_relationship
    assert_cacheable_get :show, params: {id: 1, include: 'isoCurrency,employee.post'}
    assert_response :bad_request
    assert_match /post is not a valid relationship of people/, json_response['errors'][0]['detail']
  end

  def test_invalid_include
    assert_cacheable_get :index, params: {include: 'invalid../../../../'}
    assert_response :bad_request
    assert_match /invalid is not a valid relationship of expenseEntries/, json_response['errors'][0]['detail']
  end

  def test_invalid_include_long_garbage_string
    assert_cacheable_get :index, params: {include: 'invalid.foo.bar.dfsdfs,dfsdfs.sdfwe.ewrerw.erwrewrew'}
    assert_response :bad_request
    assert_match /invalid is not a valid relationship of expenseEntries/, json_response['errors'][0]['detail']
  end

  def test_expense_entries_show_fields
    assert_cacheable_get :show, params: {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate'}}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal ['transactionDate'], json_response['data']['attributes'].keys
    assert_equal 2, json_response['included'].size
  end

  def test_expense_entries_show_fields_type_many
    assert_cacheable_get :show, params: {id: 1, include: 'isoCurrency,employee', 'fields' => {'expenseEntries' => 'transactionDate',
                                                                             'isoCurrencies' => 'id,name'}}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert json_response['data']['attributes'].key?('transactionDate')
    assert_equal 2, json_response['included'].size
  end

  def test_create_expense_entries_underscored
    set_content_type_header!
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key

    post :create, params:
      {
        data: {
          type: 'expense_entries',
          attributes: {
            transaction_date: '2014/04/15',
            cost: 50.58
          },
          relationships: {
            employee: {data: {type: 'people', id: '3'}},
            iso_currency: {data: {type: 'iso_currencies', id: 'USD'}}
          }
        },
        include: 'iso_currency,employee',
        fields: {expense_entries: 'id,transaction_date,iso_currency,cost,employee'}
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['employee']['data']['id']
    assert_equal 'USD', json_response['data']['relationships']['iso_currency']['data']['id']
    assert_equal '50.58', json_response['data']['attributes']['cost']

    delete :destroy, params: {id: json_response['data']['id']}
    assert_response :no_content
  ensure
    JSONAPI.configuration = original_config
  end

  def test_create_expense_entries_camelized_key
    set_content_type_header!
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key

    post :create, params:
      {
        data: {
          type: 'expense_entries',
          attributes: {
            transactionDate: '2014/04/15',
            cost: 50.58
          },
          relationships: {
            employee: {data: {type: 'people', id: '3'}},
            isoCurrency: {data: {type: 'iso_currencies', id: 'USD'}}
          }
        },
        include: 'isoCurrency,employee',
        fields: {expenseEntries: 'id,transactionDate,isoCurrency,cost,employee'}
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['employee']['data']['id']
    assert_equal 'USD', json_response['data']['relationships']['isoCurrency']['data']['id']
    assert_equal '50.58', json_response['data']['attributes']['cost']

    delete :destroy, params: {id: json_response['data']['id']}
    assert_response :no_content
  ensure
    JSONAPI.configuration = original_config
  end

  def test_create_expense_entries_dasherized_key
    set_content_type_header!
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key

    post :create, params:
      {
        data: {
          type: 'expense_entries',
          attributes: {
            'transaction-date' => '2014/04/15',
            cost: 50.58
          },
          relationships: {
            employee: {data: {type: 'people', id: '3'}},
            'iso-currency' => {data: {type: 'iso_currencies', id: 'USD'}}
          }
        },
        include: 'iso-currency,employee',
        fields: {'expense-entries' => 'id,transaction-date,iso-currency,cost,employee'}
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal '3', json_response['data']['relationships']['employee']['data']['id']
    assert_equal 'USD', json_response['data']['relationships']['iso-currency']['data']['id']
    assert_equal '50.58', json_response['data']['attributes']['cost']

    delete :destroy, params: {id: json_response['data']['id']}
    assert_response :no_content
  ensure
    JSONAPI.configuration = original_config
  end
end

class IsoCurrenciesControllerTest < ActionController::TestCase
  def after_teardown
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_currencies_show
    assert_cacheable_get :show, params: {id: 'USD'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
  end

  def test_create_currencies_client_generated_id
    set_content_type_header!
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_route

    post :create, params:
      {
        data: {
          type: 'iso_currencies',
          id: 'BTC',
          attributes: {
            name: 'Bit Coin',
            'country_name' => 'global',
            'minor_unit' => 'satoshi'
          }
        }
      }

    assert_response :created
    assert_equal 'BTC', json_response['data']['id']
    assert_equal 'Bit Coin', json_response['data']['attributes']['name']
    assert_equal 'global', json_response['data']['attributes']['country_name']
    assert_equal 'satoshi', json_response['data']['attributes']['minor_unit']

    delete :destroy, params: {id: json_response['data']['id']}
    assert_response :no_content
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_primary_key_sort
    assert_cacheable_get :index, params: {sort: 'id'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'CAD', json_response['data'][0]['id']
    assert_equal 'EUR', json_response['data'][1]['id']
    assert_equal 'USD', json_response['data'][2]['id']
  end

  def test_currencies_code_sort
    assert_cacheable_get :index, params: {sort: 'code'}
    assert_response :bad_request
  end

  def test_currencies_json_key_underscored_sort
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :underscored_key
    assert_cacheable_get :index, params: {sort: 'country_name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country_name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country_name']
    assert_equal 'United States', json_response['data'][2]['attributes']['country_name']

    # reverse sort
    assert_cacheable_get :index, params: {sort: '-country_name'}
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
    assert_cacheable_get :index, params: {sort: 'country-name'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country-name']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['country-name']
    assert_equal 'United States', json_response['data'][2]['attributes']['country-name']

    # reverse sort
    assert_cacheable_get :index, params: {sort: '-country-name'}
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
    assert_cacheable_get :index, params: {sort: 'CountryName'}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['CountryName']
    assert_equal 'Euro Member Countries', json_response['data'][1]['attributes']['CountryName']
    assert_equal 'United States', json_response['data'][2]['attributes']['CountryName']

    # reverse sort
    assert_cacheable_get :index, params: {sort: '-CountryName'}
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
    assert_cacheable_get :index, params: {filter: {country_name: 'Canada'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['country_name']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_camelized_key_filter
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    assert_cacheable_get :index, params: {filter: {'countryName' => 'Canada'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Canada', json_response['data'][0]['attributes']['countryName']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_currencies_json_key_custom_json_key_filter
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :upper_camelized_key
    assert_cacheable_get :index, params: {filter: {'CountryName' => 'Canada'}}
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

  def test_create_validations
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'people',
          attributes: {
            name: 'Steve Jobs',
            email: 'sj@email.zzz',
            dateJoined: DateTime.parse('2014-1-30 4:20:00 UTC +00:00')
          }
        }
      }

    assert_response :success
  end

  def test_update_link_with_dasherized_type
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'people',
          relationships: {
            'hair-cut' => {
              data: {
                type: 'hair-cuts',
                id: '1'
              }
            }
          }
        }
      }
    assert_response :success
  ensure
    JSONAPI.configuration = original_config
  end

  def test_create_validations_missing_attribute
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'people',
          attributes: {
            email: 'sj@email.zzz'
          }
        }
      }

    assert_response :unprocessable_entity
    assert_equal 2, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][1]['code']
    assert_match /dateJoined - can't be blank/, response.body
    assert_match /name - can't be blank/, response.body
  end

  def test_update_validations_missing_attribute
    set_content_type_header!
    put :update, params:
      {
        id: 3,
        data: {
          id: '3',
          type: 'people',
          attributes: {
            name: ''
          }
        }
      }

    assert_response :unprocessable_entity
    assert_equal 1, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_match /name - can't be blank/, response.body
  end

  def test_delete_locked
    initial_count = Person.count
    delete :destroy, params: {id: '3'}
    assert_response :locked
    assert_equal initial_count, Person.count
  end

  def test_invalid_filter_value
    assert_cacheable_get :index, params: {filter: {name: 'L'}}
    assert_response :bad_request
  end

  def test_invalid_filter_value_for_get_related_resources
    assert_cacheable_get :get_related_resources, params: {
          hair_cut_id: 1,
          relationship: 'people',
          source: 'hair_cuts',
          filter: {name: 'L'}
        }

    assert_response :bad_request
  end

  def test_valid_filter_value
    assert_cacheable_get :index, params: {filter: {name: 'Joe Author'}}
    assert_response :success
    assert_equal json_response['data'].size, 1
    assert_equal json_response['data'][0]['id'], '1'
    assert_equal json_response['data'][0]['attributes']['name'], 'Joe Author'
  end

  def test_get_related_resource_no_namespace
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    JSONAPI.configuration.route_format = :underscored_key
    assert_cacheable_get :get_related_resource, params: {post_id: '2', relationship: 'author', source:'posts'}
    assert_response :success
    assert_hash_equals(
      {
        data: {
          id: '1',
          type: 'people',
          attributes: {
            name: 'Joe Author',
            email: 'joe@xyz.fake',
            "date-joined" => '2013-08-07 16:25:00 -0400'
          },
          links: {
            self: 'http://test.host/people/1'
          },
          relationships: {
            comments: {
              links: {
                self: 'http://test.host/people/1/relationships/comments',
                related: 'http://test.host/people/1/comments'
              }
            },
            posts: {
              links: {
                self: 'http://test.host/people/1/relationships/posts',
                related: 'http://test.host/people/1/posts'
              }
            },
            preferences: {
              links: {
                self: 'http://test.host/people/1/relationships/preferences',
                related: 'http://test.host/people/1/preferences'
              }
            },
            "hair-cut" => {
              "links" => {
                "self" => "http://test.host/people/1/relationships/hair_cut",
                "related" => "http://test.host/people/1/hair_cut"
              }
            },
            vehicles: {
              links: {
                self: "http://test.host/people/1/relationships/vehicles",
                related: "http://test.host/people/1/vehicles"
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

  def test_get_related_resource_nil
    assert_cacheable_get :get_related_resource, params: {post_id: '17', relationship: 'author', source:'posts'}
    assert_response :success
    assert_hash_equals json_response,
                       {
                         data: nil
                       }

  end
end

class BooksControllerTest < ActionController::TestCase
  def test_books_include_correct_type
    $test_user = Person.find(1)
    assert_cacheable_get :index, params: {filter: {id: '1'}, include: 'authors'}
    assert_response :success
    assert_equal 'authors', json_response['included'][0]['type']
  end

  def test_destroy_relationship_has_and_belongs_to_many
    JSONAPI.configuration.use_relationship_reflection = false

    assert_equal 2, Book.find(2).authors.count

    delete :destroy_relationship, params: {book_id: 2, relationship: 'authors', data: [{type: 'authors', id: 1}]}
    assert_response :no_content
    assert_equal 1, Book.find(2).authors.count
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_destroy_relationship_has_and_belongs_to_many_reflect
    JSONAPI.configuration.use_relationship_reflection = true

    assert_equal 2, Book.find(2).authors.count

    delete :destroy_relationship, params: {book_id: 2, relationship: 'authors', data: [{type: 'authors', id: 1}]}
    assert_response :no_content
    assert_equal 1, Book.find(2).authors.count

  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def test_index_with_caching_enabled_uses_context
    assert_cacheable_get :index
    assert_response :success
    assert json_response['data'][0]['attributes']['title'] = 'Title'
  end
end

class Api::V5::PostsControllerTest < ActionController::TestCase
  def test_show_post_no_relationship_routes_exludes_relationships
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_nil json_response['data']['relationships']
  end

  def test_exclude_resource_links
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_equal 1, json_response['data']['links'].length

    Api::V5::PostResource.exclude_links :default
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_nil json_response['data']['links']

    Api::V5::PostResource.exclude_links [:self]
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_nil json_response['data']['links']

    Api::V5::PostResource.exclude_links :none
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_nil json_response['data']['relationships']
    assert_equal 1, json_response['data']['links'].length
  ensure
    Api::V5::PostResource.exclude_links :none
  end

  def test_show_post_no_relationship_route_include
    get :show, params: {id: '1', include: 'author'}
    assert_response :success
    assert_equal '1', json_response['data']['relationships']['author']['data']['id']
    assert_nil json_response['data']['relationships']['tags']
    assert_equal '1', json_response['included'][0]['id']
    assert_equal 'people', json_response['included'][0]['type']
    assert_equal 'joe@xyz.fake', json_response['included'][0]['attributes']['email']
  end
end

class Api::V5::PaintersControllerTest < ActionController::TestCase
  def test_index_with_included_resources_with_filters
    # There are two painters, but by filtering the included relationship, the
    # painters are limited due to the join, thus only the painter with oil
    # paintings is returned.
    get :index, params: { include: 'paintings', filter: { 'paintings.category' => 'oil' } }
    assert_response :success
    assert_equal 1, json_response['data'].size, 'Size of data is wrong'
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 2, json_response['included'].size, 'Size of included data is wrong'
    assert_equal '4', json_response['included'][0]['id']
    assert_equal '5', json_response['included'][1]['id']
  end

  def test_index_with_filters_and_included_resources_with_filters
    get :index, params: { include: 'paintings', filter: { 'name' => 'Wyspianski', 'paintings.category' => 'oil' } }

    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 2, json_response['included'].size
    assert_equal '4', json_response['included'][0]['id']
  end

  def test_index_with_filters_and_included_resources_with_multiple_filters
    # Painting 5 is the genuine, but painting 6 is a fake. Verify that multiple nested filters are merged and only the oil painting is returned.
    get :index, params: { include: 'paintings', filter: { 'name' => 'Wyspianski', 'paintings.category' => 'oil', 'paintings.title' => 'Motherhood' } }

    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 1, json_response['included'].size
    assert_equal '5', json_response['included'][0]['id']
  end

  def test_show_with_filters_and_included_resources_with_filters
    get :show, params: { id: 1, include: 'paintings', filter: { 'paintings.category' => 'oil' } }
    assert_response :success
    assert_equal '1', json_response['data']['id']
    assert_equal 2, json_response['included'].size
    assert_equal '4', json_response['included'][0]['id']
  end

  def test_show_with_filters_and_no_included_resources
    get :show, params: { id: 1, filter: { 'paintings.category' => 'oil' } }
    assert_response :bad_request
    assert_equal('Filter not allowed', json_response['errors'][0]['title'])
    assert_equal('category is not allowed.', json_response['errors'][0]['detail'])
  end
end

class Api::V5::CollectorsControllerTest < ActionController::TestCase
  def test_index_with_custom_filter_that_has_dot
    get :index, params: {
        filter: {
            'name' => 'Alice',
            'painting.title_equals': 'Helenka'
        }
    }

    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    refute json_response.key?('included')
  end
end

class Api::V5::AuthorsControllerTest < ActionController::TestCase
  def test_get_person_as_author
    assert_cacheable_get :index, params: {filter: {id: '1'}}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
    assert_equal 'authors', json_response['data'][0]['type']
    assert_equal 'Joe Author', json_response['data'][0]['attributes']['name']
    assert_nil json_response['data'][0]['attributes']['email']
  end

  def test_show_person_as_author
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_equal '1', json_response['data']['id']
    assert_equal 'authors', json_response['data']['type']
    assert_equal 'Joe Author', json_response['data']['attributes']['name']
    assert_nil json_response['data']['attributes']['email']
  end

  def test_get_person_as_author_by_name_filter
    assert_cacheable_get :index, params: {filter: {name: 'thor'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
    assert_equal '1', json_response['data'][0]['id']
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

    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_equal '1', json_response['data']['id']
    assert_equal 'Hardcoded value', json_response['data']['meta']['fixed']
    assert_equal 'authors: http://test.host/api/v5/authors/1', json_response['data']['meta']['computed']
    assert_equal 'bar', json_response['data']['meta']['computed_foo']
    assert_equal 'test value', json_response['data']['meta']['testKey']

  ensure
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V5::AuthorResource.class_eval do
      def meta(options)
        # :nocov:
        { }
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

    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_equal '1', json_response['data']['id']
    assert_equal 'Hardcoded value', json_response['data']['meta']['custom_hash']['fixed']
    assert_equal 'authors: http://test.host/api/v5/authors/1', json_response['data']['meta']['custom_hash']['computed']
    assert_equal 'bar', json_response['data']['meta']['custom_hash']['computed_foo']
    assert_equal 'test value', json_response['data']['meta']['custom_hash']['testKey']

  ensure
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V5::AuthorResource.class_eval do
      def meta(options)
        # :nocov:
        { }
        # :nocov:
      end
    end
  end
end

class Api::V2::BooksControllerTest < ActionController::TestCase
  def test_get_related_resources_with_filters
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :get_related_resources,
                         params: {
                           author_id: '1',
                           relationship: 'books',
                           source: 'api/v2/authors',
                           filter: { fiction: 'true' }
                         }
    assert_response :success
    assert_equal 1, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V2::BooksControllerTest < ActionController::TestCase
  def test_get_related_resources_with_filters
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :get_related_resources,
                         params: {
                           author_id: '1',
                           relationship: 'books',
                           source: 'api/v2/authors',
                           filter: { fiction: 'true' }
                         }
    assert_response :success
    assert_equal 1, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_get_related_resources_with_filters_2
    # Admin user can find an author's banned books
    $test_user = Person.find(5)
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :get_related_resources,
                         params: {
                           author_id: '1',
                           relationship: 'books',
                           source: 'api/v2/authors',
                           filter: { banned: 'true' }
                         }
    assert_response :success
    assert_equal 1, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration = original_config
  end
end

class BreedsControllerTest < ActionController::TestCase
  # Note: Breed names go through the TitleValueFormatter

  def test_poro_index
    assert_cacheable_get :index
    assert_response :success
    assert_equal '0', json_response['data'][0]['id']
    assert_equal 'Persian', json_response['data'][0]['attributes']['name']
  end

  def test_poro_show
    assert_cacheable_get :show, params: {id: '0'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal '0', json_response['data']['id']
    assert_equal 'Persian', json_response['data']['attributes']['name']
  end

  def test_poro_show_multiple
    assert_cacheable_get :show, params: {id: '0,2'}

    assert_response :bad_request
    assert_match /0,2 is not a valid value for id/, response.body
  end

  def test_poro_create_simple
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'breeds',
          attributes: {
            name: 'tabby'
          }
        }
      }

    assert_response :accepted
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Tabby', json_response['data']['attributes']['name']
  end

  def test_poro_create_validation_error
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'breeds',
          attributes: {
            name: ''
          }
        }
      }

    assert_equal 1, json_response['errors'].size
    assert_equal JSONAPI::VALIDATION_ERROR, json_response['errors'][0]['code']
    assert_match /name - can't be blank/, response.body
  end

  def test_poro_create_update
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'breeds',
          attributes: {
            name: 'CALIC'
          }
        }
      }

    assert_response :accepted
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Calic', json_response['data']['attributes']['name']

    put :update, params:
      {
        id: json_response['data']['id'],
        data: {
          id: json_response['data']['id'],
          type: 'breeds',
          attributes: {
            name: 'calico'
          }
        }
      }
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Calico', json_response['data']['attributes']['name']
  end

  def test_poro_delete
    initial_count = $breed_data.breeds.keys.count
    delete :destroy, params: {id: '3'}
    assert_response :no_content
    assert_equal initial_count - 1, $breed_data.breeds.keys.count
  end

end

class Api::V2::PreferencesControllerTest < ActionController::TestCase
  def test_show_singleton_resource_without_id
    $test_user = Person.find(1)

    assert_cacheable_get :show
    assert_response :success
  end

  def test_update_singleton_resource_without_id
    set_content_type_header!
    $test_user = Person.find(1)
    patch :update, params: {
      data: {
        id: "1",
        type: "preferences",
        attributes: {
        }
      }
    }
    assert_response :success
  end
end

class Api::V1::PostsControllerTest < ActionController::TestCase
  def test_show_post_namespaced
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert_equal 'http://test.host/api/v1/posts/1/relationships/writer', json_response['data']['relationships']['writer']['links']['self']
  end

  def test_show_post_namespaced_include
    assert_cacheable_get :show, params: {id: '1', include: 'writer'}
    assert_response :success
    assert_equal '1', json_response['data']['relationships']['writer']['data']['id']
    assert_nil json_response['data']['relationships']['tags']
    assert_equal '1', json_response['included'][0]['id']
    assert_equal 'writers', json_response['included'][0]['type']
    assert_equal 'joe@xyz.fake', json_response['included'][0]['attributes']['email']
  end

  def test_index_filter_on_relationship_namespaced
    assert_cacheable_get :index, params: {filter: {writer: '1'}}
    assert_response :success
    assert_equal 3, json_response['data'].size
  end

  def test_sorting_desc_namespaced
    assert_cacheable_get :index, params: {sort: '-title'}

    assert_response :success
    assert_equal "Update This Later - Multiple", json_response['data'][0]['attributes']['title']
  end

  def test_create_simple_namespaced
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'posts',
          attributes: {
            title: 'JR - now with Namespacing',
            body: 'JSONAPIResources is the greatest thing since unsliced bread now that it has namespaced resources.'
          },
          relationships: {
            writer: { data: {type: 'writers', id: '3'}}
          }
        }
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'JR - now with Namespacing', json_response['data']['attributes']['title']
    assert_equal 'JSONAPIResources is the greatest thing since unsliced bread now that it has namespaced resources.',
                 json_response['data']['attributes']['body']
  end

end

class FactsControllerTest < ActionController::TestCase
  def test_type_formatting
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :camelized_key
    assert_cacheable_get :show, params: {id: '1'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Jane Author', json_response['data']['attributes']['spouseName']
    assert_equal 'First man to run across Antartica.', json_response['data']['attributes']['bio']
    assert_equal 23.89/45.6, json_response['data']['attributes']['qualityRating']
    assert_equal '47000.56', json_response['data']['attributes']['salary']
    assert_equal '2013-08-07T20:25:00.000Z', json_response['data']['attributes']['dateTimeJoined']
    assert_equal '1965-06-30', json_response['data']['attributes']['birthday']
    assert_equal '2000-01-01T20:00:00.000Z', json_response['data']['attributes']['bedtime']
    assert_equal 'abc', json_response['data']['attributes']['photo']
    assert_equal false, json_response['data']['attributes']['cool']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_create_with_invalid_data
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.json_key_format = :dasherized_key
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'facts',
          attributes: {
            bio: '',
            :"quality-rating" => '',
            :"spouse-name" => '',
            salary: 100000,
            :"date-time-joined" => '',
            birthday: '',
            bedtime: '',
            photo: 'abc',
            cool: false
          },
          relationships: {
          }
        }
      }

    assert_response :unprocessable_entity

    assert_equal "/data/attributes/spouse-name", json_response['errors'][0]['source']['pointer']
    assert_equal "can't be blank", json_response['errors'][0]['title']
    assert_equal "spouse-name - can't be blank", json_response['errors'][0]['detail']

    assert_equal "/data/attributes/bio", json_response['errors'][1]['source']['pointer']
    assert_equal "can't be blank", json_response['errors'][1]['title']
    assert_equal "bio - can't be blank", json_response['errors'][1]['detail']
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V2::BooksControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :dasherized_key
    $test_user = Person.find(1)
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
    assert_cacheable_get :index, params: {include: 'book-comments'}
    JSONAPI.configuration.top_level_meta_include_record_count = false

    assert_response :success
    assert_equal 901, json_response['meta']['record-count']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_page_count_in_meta
    Api::V2::BookResource.paginator :paged
    JSONAPI.configuration.top_level_meta_include_page_count = true
    assert_cacheable_get :index, params: {include: 'book-comments'}
    JSONAPI.configuration.top_level_meta_include_page_count = false

    assert_response :success
    assert_equal 91, json_response['meta']['page-count']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_record_count_in_meta_custom_name
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.top_level_meta_record_count_key = 'total_records'

    assert_cacheable_get :index, params: {include: 'book-comments'}
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

    assert_cacheable_get :index, params: {include: 'book-comments'}
    JSONAPI.configuration.top_level_meta_include_page_count = false
    JSONAPI.configuration.top_level_meta_page_count_key = :page_count

    assert_response :success
    assert_equal 91, json_response['meta']['total-pages']
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_no_params_includes_query_count_one_level
    Api::V2::BookResource.paginator :offset

    assert_query_count(3) do
      assert_cacheable_get :index, params: {include: 'book-comments'}
    end
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_no_params_includes_query_count_two_levels
    Api::V2::BookResource.paginator :offset

    assert_query_count(4) do
      assert_cacheable_get :index, params: {include: 'book-comments,book-comments.author'}
    end
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
  end

  def test_books_offset_pagination_bad_page_param
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: {offset_bad: 50, limit: 12}}
    assert_response :bad_request
    assert_match /offset_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: {offset: 50, limit: 1000}}
    assert_response :bad_request
    assert_match /Limit exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: {offset: 50, limit: -1}}
    assert_response :bad_request
    assert_match /-1 is not a valid value for limit page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_bad_param_offset_less_than_zero
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: {offset: -1, limit: 20}}
    assert_response :bad_request
    assert_match /-1 is not a valid value for offset page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_offset_pagination_invalid_page_format
    Api::V2::BookResource.paginator :offset

    assert_cacheable_get :index, params: {page: 50}
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

    assert_cacheable_get :index, params: {page: {size: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_paged_pagination
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: {number: 3, size: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 24', json_response['data'][0]['attributes']['title']
  end

  def test_books_paged_pagination_bad_page_param
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: {number_bad: 50, size: 12}}
    assert_response :bad_request
    assert_match /number_bad is not an allowed page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_to_large
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: {number: 50, size: 1000}}
    assert_response :bad_request
    assert_match /size exceeds maximum page size of 20./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_bad_param_value_limit_too_small
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: {number: 50, size: -1}}
    assert_response :bad_request
    assert_match /-1 is not a valid value for size page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_invalid_page_format_incorrect
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: 'qwerty'}
    assert_response :bad_request
    assert_match /0 is not a valid value for number page parameter./, json_response['errors'][0]['detail']
  end

  def test_books_paged_pagination_invalid_page_format_interpret_int
    Api::V2::BookResource.paginator :paged

    assert_cacheable_get :index, params: {page: 3}
    assert_response :success
    assert_equal 10, json_response['data'].size
    assert_equal 'Book 20', json_response['data'][0]['attributes']['title']
  end

  def test_books_included_paged
    Api::V2::BookResource.paginator :offset

    assert_query_count(3) do
      assert_cacheable_get :index, params: {filter: {id: '0'}, include: 'book-comments'}
    end
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
  end

  def test_books_banned_non_book_admin
    $test_user = Person.find(1)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(2) do
      assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}}
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_includes_switched
    $test_user = Person.find(1)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(3) do
      assert_cacheable_get :index, params: {page: {offset: 0, limit: 12}, include: 'book-comments'}
    end

    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 130, json_response['included'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 26, json_response['data'][0]['relationships']['book-comments']['data'].size
    assert_equal 'book-comments', json_response['included'][0]['type']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_includes_nested_includes
    $test_user = Person.find(1)
    JSONAPI.configuration.top_level_meta_include_record_count = true
    Api::V2::BookResource.paginator :offset
    assert_query_count(4) do
      assert_cacheable_get :index, params: {page: {offset: 0, limit: 12}, include: 'book-comments.author'}
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 135, json_response['included'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_admin
    $test_user = Person.find(5)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(2) do
      assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}, filter: {banned: 'true'}}
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 651', json_response['data'][0]['attributes']['title']
    assert_equal 99, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_not_banned_admin
    $test_user = Person.find(5)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(2) do
      assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}, filter: {banned: 'false'}, fields: {books: 'id,title'}}
    end
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_banned_non_book_admin_overlapped
    $test_user = Person.find(1)
    Api::V2::BookResource.paginator :offset
    JSONAPI.configuration.top_level_meta_include_record_count = true
    assert_query_count(2) do
      assert_cacheable_get :index, params: {page: {offset: 590, limit: 20}}
    end
    assert_response :success
    assert_equal 20, json_response['data'].size
    assert_equal 'Book 590', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration.top_level_meta_include_record_count = false
  end

  def test_books_included_exclude_unapproved
    $test_user = Person.find(1)
    Api::V2::BookResource.paginator :none

    assert_query_count(2) do
      assert_cacheable_get :index, params: {filter: {id: '0,1,2,3,4'}, include: 'book-comments'}
    end
    assert_response :success
    assert_equal 5, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 130, json_response['included'].size
    assert_equal 26, json_response['data'][0]['relationships']['book-comments']['data'].size
  end

  def test_books_included_all_comments_for_admin
    $test_user = Person.find(5)
    Api::V2::BookResource.paginator :none

    assert_cacheable_get :index, params: {filter: {id: '0,1,2,3,4'}, include: 'book-comments'}
    assert_response :success
    assert_equal 5, json_response['data'].size
    assert_equal 'Book 0', json_response['data'][0]['attributes']['title']
    assert_equal 255, json_response['included'].size
    assert_equal 51, json_response['data'][0]['relationships']['book-comments']['data'].size
  end

  def test_books_filter_by_book_comment_id_limited_user
    $test_user = Person.find(1)
    assert_cacheable_get :index, params: {filter: {book_comments: '0,52' }}
    assert_response :success
    assert_equal 1, json_response['data'].size
  end

  def test_books_filter_by_book_comment_id_admin_user
    $test_user = Person.find(5)
    assert_cacheable_get :index, params: {filter: {book_comments: '0,52' }}
    assert_response :success
    assert_equal 2, json_response['data'].size
  end

  def test_books_create_unapproved_comment_limited_user_using_relation_name
    set_content_type_header!
    $test_user = Person.find(1)

    book_comment = BookComment.create(body: 'Not Approved dummy comment', approved: false)
    post :create_relationship, params: {book_id: 1, relationship: 'book_comments', data: [{type: 'book_comments', id: book_comment.id}]}

    # Note the not_found response is coming from the BookComment's overridden records method, not the relation
    assert_response :not_found

  ensure
    book_comment.delete
  end

  def test_books_create_approved_comment_limited_user_using_relation_name
    set_content_type_header!
    $test_user = Person.find(1)

    book_comment = BookComment.create(body: 'Approved dummy comment', approved: true)
    post :create_relationship, params: {book_id: 1, relationship: 'book_comments', data: [{type: 'book_comments', id: book_comment.id}]}
    assert_response :success

  ensure
    book_comment.delete
  end

  def test_books_delete_unapproved_comment_limited_user_using_relation_name
    $test_user = Person.find(1)

    book_comment = BookComment.create(book_id: 1, body: 'Not Approved dummy comment', approved: false)
    delete :destroy_relationship, params: {book_id: 1, relationship: 'book_comments', data: [{type: 'book_comments', id: book_comment.id}]}
    assert_response :not_found

  ensure
    book_comment.delete
  end

  def test_books_delete_approved_comment_limited_user_using_relation_name
    $test_user = Person.find(1)

    book_comment = BookComment.create(book_id: 1, body: 'Approved dummy comment', approved: true)
    delete :destroy_relationship, params: {book_id: 1, relationship: 'book_comments', data: [{type: 'book_comments', id: book_comment.id}]}
    assert_response :no_content

  ensure
    book_comment.delete
  end

  def test_books_delete_approved_comment_limited_user_using_relation_name_reflected
    JSONAPI.configuration.use_relationship_reflection = true
    $test_user = Person.find(1)

    book_comment = BookComment.create(book_id: 1, body: 'Approved dummy comment', approved: true)
    delete :destroy_relationship, params: {book_id: 1, relationship: 'book_comments', data: [{type: 'book_comments', id: book_comment.id}]}
    assert_response :no_content

  ensure
    JSONAPI.configuration.use_relationship_reflection = false
    book_comment.delete
  end
end

class Api::V2::BookCommentsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :dasherized_key
    Api::V2::BookCommentResource.paginator :none
    $test_user = Person.find(1)
  end

  def test_book_comments_all_for_admin
    $test_user = Person.find(5)
    assert_query_count(1) do
      assert_cacheable_get :index
    end
    assert_response :success
    assert_equal 255, json_response['data'].size
  end

  def test_book_comments_unapproved_context_based
    $test_user = Person.find(5)
    assert_query_count(1) do
      assert_cacheable_get :index, params: {filter: {approved: 'false'}}
    end
    assert_response :success
    assert_equal 125, json_response['data'].size
  end

  def test_book_comments_exclude_unapproved_context_based
    $test_user = Person.find(1)
    assert_query_count(1) do
      assert_cacheable_get :index
    end
    assert_response :success
    assert_equal 130, json_response['data'].size
  end
end

class Api::V4::BooksControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_books_offset_pagination_meta
    original_config = JSONAPI.configuration.dup
    Api::V4::BookResource.paginator :offset
    assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 901, json_response['meta']['totalRecords']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_books_operation_links
    original_config = JSONAPI.configuration.dup
    Api::V4::BookResource.paginator :offset
    assert_cacheable_get :index, params: {page: {offset: 50, limit: 12}}
    assert_response :success
    assert_equal 12, json_response['data'].size
    assert_equal 'Book 50', json_response['data'][0]['attributes']['title']
    assert_equal 5, json_response['links'].size
    assert_equal 'https://test_corp.com', json_response['links']['spec']
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
  def test_save_model_callbacks
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'planets',
          attributes: {
            name: 'Zeus',
            description: 'The largest planet in the solar system. Discovered in 2015.'
          }
        }
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'Zeus', json_response['data']['attributes']['name']
  end

  def test_save_model_callbacks_fail
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'planets',
          attributes: {
            name: 'Pluto',
            description: 'Yes, it is a planet.'
          }
        }
      }

    assert_response :unprocessable_entity
    assert_match /Save failed or was cancelled/, json_response['errors'][0]['detail']
  end
end

class Api::V1::MoonsControllerTest < ActionController::TestCase
  def test_get_related_resource
    assert_cacheable_get :get_related_resource, params: {crater_id: 'S56D', relationship: 'moon', source: "api/v1/craters"}
    assert_response :success
    assert_hash_equals({
                         data: {
                           id: "1",
                           type: "moons",
                           links: {self: "http://test.host/api/v1/moons/1"},
                           attributes: {name: "Titan", description: "Best known of the Saturn moons."},
                           relationships: {
                             planet: {links: {self: "http://test.host/api/v1/moons/1/relationships/planet", related: "http://test.host/api/v1/moons/1/planet"}},
                             craters: {links: {self: "http://test.host/api/v1/moons/1/relationships/craters", related: "http://test.host/api/v1/moons/1/craters"}}}
                         }
                       }, json_response)
  end

  def test_get_related_resources_with_select_some_db_columns
    PlanetResource.paginator :paged
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.top_level_meta_include_record_count = true
    JSONAPI.configuration.json_key_format = :dasherized_key
    assert_cacheable_get :get_related_resources, params: {planet_id: '1', relationship: 'moons', source: 'api/v1/planets'}
    assert_response :success
    assert_equal 1, json_response['meta']['record-count']
  ensure
    JSONAPI.configuration = original_config
  end
end

class Api::V1::CratersControllerTest < ActionController::TestCase
  def test_show_single
    assert_cacheable_get :show, params: {id: 'S56D'}
    assert_response :success
    assert json_response['data'].is_a?(Hash)
    assert_equal 'S56D', json_response['data']['attributes']['code']
    assert_equal 'Very large crater', json_response['data']['attributes']['description']
    assert_nil json_response['included']
  end

  def test_get_related_resources
    assert_cacheable_get :get_related_resources, params: {moon_id: '1', relationship: 'craters', source: "api/v1/moons"}
    assert_response :success
    assert_hash_equals({
                         data: [
                           {
                             id:"A4D3",
                             type:"craters",
                             links:{self: "http://test.host/api/v1/craters/A4D3"},
                             attributes:{code: "A4D3", description: "Small crater"},
                             relationships:{moon: {links: {self: "http://test.host/api/v1/craters/A4D3/relationships/moon", related: "http://test.host/api/v1/craters/A4D3/moon"}}}
                           },
                           {
                             id: "S56D",
                             type: "craters",
                             links:{self: "http://test.host/api/v1/craters/S56D"},
                             attributes:{code: "S56D", description: "Very large crater"},
                             relationships:{moon: {links: {self: "http://test.host/api/v1/craters/S56D/relationships/moon", related: "http://test.host/api/v1/craters/S56D/moon"}}}
                           }
                         ]
                       }, json_response)
  end

  def test_get_related_resources_filtered
    $test_user = Person.find(1)
    get :get_related_resources, params: {moon_id: '1', relationship: 'craters', source: "api/v1/moons", filter: {description: 'Small crater'}}
    assert_response :success
    assert_hash_equals({
                           data: [
                               {
                                   id:"A4D3",
                                   type:"craters",
                                   links:{self: "http://test.host/api/v1/craters/A4D3"},
                                   attributes:{code: "A4D3", description: "Small crater"},
                                   relationships:{moon: {links: {self: "http://test.host/api/v1/craters/A4D3/relationships/moon", related: "http://test.host/api/v1/craters/A4D3/moon"}}}
                               }
                           ]
                       }, json_response)
  end

  def test_show_relationship
    assert_cacheable_get :show_relationship, params: {crater_id: 'S56D', relationship: 'moon'}

    assert_response :success
    assert_equal "moons", json_response['data']['type']
    assert_equal "1", json_response['data']['id']
  end
end

class CarsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
  end

  def test_create_sti
    set_content_type_header!
    post :create, params:
      {
        data: {
          type: 'cars',
          attributes: {
            make: 'Toyota',
            model: 'Tercel',
            serialNumber: 'asasdsdadsa13544235',
            driveLayout: 'FWD'
          }
        }
      }

    assert_response :created
    assert json_response['data'].is_a?(Hash)
    assert_equal 'cars', json_response['data']['type']
    assert_equal 'Toyota', json_response['data']['attributes']['make']
    assert_equal 'FWD', json_response['data']['attributes']['driveLayout']
  end
end

class VehiclesControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :camelized_key
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

class AuthorsControllerTest < ActionController::TestCase
  def setup
    JSONAPI.configuration.json_key_format = :dasherized_key
  end

  def test_include_has_one_exists
    assert_cacheable_get :index, params: {filter: {id: '2'}, include: 'author-detail'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '2', json_response['data'][0]['relationships']['author-detail']['data']['id']
    assert_equal 1, json_response['included'].size
  end

  def test_include_has_one_nonexistent
    assert_cacheable_get :index, params: {filter: {id: '3'}, include: 'author-detail'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_nil json_response['data'][0]['relationships']['author-detail']['data']
    assert_nil json_response['included']
  end
end

class AuthorDetailsControllerTest < ActionController::TestCase
  def test_author_details_index_include_has_one_does_exist
    assert_cacheable_get :index, params: {filter: {id: '1'}, include: 'author'}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_equal '1', json_response['data'][0]['relationships']['author']['data']['id']
    assert_equal 1, json_response['included'].size
  end

  def test_author_details_index_include_has_one_does_not_exist
    assert_cacheable_get :index, params: {filter: {id: '3'}, include: 'author'}, test_options: {allowed_extra_queries: 1}
    assert_response :success
    assert_equal 1, json_response['data'].size
    assert_nil json_response['data'][0]['relationships']['author']['data']
    assert_nil json_response['included']
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

    assert_cacheable_get :show, params: {id: '1'}
    assert_response 500
    assert_match /Internal Server Error/, json_response['errors'][0]['detail']
  end

  def test_not_whitelisted_error_in_controller
    original_config = JSONAPI.configuration.dup
    JSONAPI.configuration.exception_class_whitelist = []
    assert_cacheable_get :show, params: {id: '1'}
    assert_response 500
    assert_match /Internal Server Error/, json_response['errors'][0]['detail']
  ensure
    JSONAPI.configuration = original_config
  end

  def test_whitelisted_error_in_controller
    original_config = JSONAPI.configuration.dup
    $PostProcessorRaisesErrors = true
    JSONAPI.configuration.exception_class_whitelist = [PostsController::SubSpecialError]
    assert_raises PostsController::SubSpecialError do
      assert_cacheable_get :show, params: {id: '1'}
    end
  ensure
    JSONAPI.configuration = original_config
    $PostProcessorRaisesErrors = false
  end
end

class Api::V6::PostsControllerTest < ActionController::TestCase
  def test_caching_with_join_from_resource_with_sql_fragment
    assert_cacheable_get :index, params: {include: 'section'}
    assert_response :success
  end
end

class Api::V6::SectionsControllerTest < ActionController::TestCase
  def test_caching_with_join_to_resource_with_sql_fragment
    assert_cacheable_get :index, params: {include: 'posts'}
    assert_response :success
  end
end

class Api::BoxesControllerTest < ActionController::TestCase
  def test_complex_includes_base
    assert_cacheable_get :index
    assert_response :success
  end

  def test_complex_includes_filters_nil_includes
    assert_cacheable_get :index, params: {include: ',,'}
    assert_response :success
  end

  def test_complex_includes_two_level
    assert_cacheable_get :index, params: {include: 'things,things.user'}

    assert_response :success

    # The test is hardcoded with the include order. This should be changed at some point since either thing could come first and still be valid
    assert_equal '1', json_response['included'][0]['id']
    assert_equal 'things', json_response['included'][0]['type']
    assert_equal '1',  json_response['included'][0]['relationships']['user']['data']['id']
    assert_nil json_response['included'][0]['relationships']['things']['data']

    assert_equal '2', json_response['included'][1]['id']
    assert_equal 'things', json_response['included'][1]['type']
    assert_equal '1', json_response['included'][1]['relationships']['user']['data']['id']
    assert_nil json_response['included'][1]['relationships']['things']['data']

    assert_equal '1', json_response['included'][2]['id']
    assert_equal 'users', json_response['included'][2]['type']
    assert_nil json_response['included'][2]['relationships']['things']['data']
  end

  def test_complex_includes_things_nested_things
    assert_cacheable_get :index, params: {include: 'things,things.things'}

    assert_response :success

    # The test is hardcoded with the include order. This should be changed at some point since either thing could come first and still be valid
    assert_equal '2', json_response['included'][0]['id']
    assert_equal 'things', json_response['included'][0]['type']
    assert_nil json_response['included'][0]['relationships']['user']['data']
    assert_equal '1', json_response['included'][0]['relationships']['things']['data'][0]['id']

    assert_equal '1', json_response['included'][1]['id']
    assert_equal 'things', json_response['included'][1]['type']
    assert_nil json_response['included'][1]['relationships']['user']['data']
    assert_equal '2', json_response['included'][1]['relationships']['things']['data'][0]['id']
  end

  def test_complex_includes_nested_things_secondary_users
    assert_cacheable_get :index, params: {include: 'things,things.user,things.things'}

    assert_response :success

    # The test is hardcoded with the include order. This should be changed at some point since either thing could come first and still be valid
    assert_equal '1', json_response['included'][2]['id']
    assert_equal 'users', json_response['included'][2]['type']
    assert_nil json_response['included'][2]['relationships']['things']['data']

    assert_equal '2', json_response['included'][0]['id']
    assert_equal 'things', json_response['included'][0]['type']
    assert_equal '1',  json_response['included'][0]['relationships']['user']['data']['id']
    assert_equal '1',  json_response['included'][0]['relationships']['things']['data'][0]['id']

    assert_equal '1', json_response['included'][1]['id']
    assert_equal 'things', json_response['included'][1]['type']
    assert_equal '1',  json_response['included'][1]['relationships']['user']['data']['id']
    assert_equal '2',  json_response['included'][1]['relationships']['things']['data'][0]['id']
  end
end
