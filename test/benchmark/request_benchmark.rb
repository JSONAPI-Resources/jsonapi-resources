# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class RequestBenchmark < IntegrationBenchmark
  def setup
    super
    $test_user = Person.find(1)
  end

  def bench_large_index_request_uncached
    10.times do
      assert_jsonapi_get '/api/v2/books?include=bookComments,bookComments.author'
    end
  end

  def bench_large_index_request_caching
    cache = ActiveSupport::Cache::MemoryStore.new
    with_resource_caching(cache) do
      10.times do
        assert_jsonapi_get '/api/v2/books?include=bookComments,bookComments.author'
      end
    end
  end
end
