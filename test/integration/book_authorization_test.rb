require File.expand_path('../../test_helper', __FILE__)

class BookAuthorizationTest < ActionDispatch::IntegrationTest
  def setup
    DatabaseCleaner.start
    JSONAPI.configuration.json_key_format = :underscored_key
    JSONAPI.configuration.route_format = :underscored_route
    Api::V2::BookResource.paginator :offset
  end

  def test_restricted_records_primary
    Api::V2::BookResource.paginator :none

    # Not a book admin
    $test_user = Person.find(1001)
    assert_cacheable_jsonapi_get '/api/v2/books?filter[title]=Book%206'
    assert_equal 12, json_response['data'].size

    # book_admin
    $test_user = Person.find(1005)
    assert_cacheable_jsonapi_get '/api/v2/books?filter[title]=Book%206'
    assert_equal 111, json_response['data'].size
  end

  def test_restricted_records_related
    Api::V2::BookResource.paginator :none

    # Not a book admin
    $test_user = Person.find(1001)
    assert_cacheable_jsonapi_get '/api/v2/authors/1002/books'
    assert_equal 1, json_response['data'].size

    # book_admin
    $test_user = Person.find(1005)
    assert_cacheable_jsonapi_get '/api/v2/authors/1002/books'
    assert_equal 2, json_response['data'].size
  end
end
