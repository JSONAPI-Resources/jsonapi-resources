# frozen_string_literal: true

require File.expand_path('../../test_helper', __dir__)
require 'jsonapi-resources'

class OffsetPaginatorTest < ActiveSupport::TestCase
  def test_offset_default_page_params
    params = ActionController::Parameters.new(
      {}
    )

    paginator = OffsetPaginator.new(params)

    assert_equal JSONAPI.configuration.default_page_size, paginator.limit
    assert_equal 0, paginator.offset
  end

  def test_offset_parse_page_params_default_offset
    params = ActionController::Parameters.new(
      {
        limit: 20
      }
    )

    paginator = OffsetPaginator.new(params)

    assert_equal 20, paginator.limit
    assert_equal 0, paginator.offset
  end

  def test_offset_parse_page_params
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 7
      }
    )

    paginator = OffsetPaginator.new(params)

    assert_equal 5, paginator.limit
    assert_equal 7, paginator.offset
  end

  def test_offset_parse_page_params_limit_too_large
    params = ActionController::Parameters.new(
      {
        limit: 50,
        offset: 0
      }
    )

    assert_raises JSONAPI::Exceptions::InvalidPageValue do
      OffsetPaginator.new(params)
    end
  end

  def test_offset_parse_page_params_not_allowed
    params = ActionController::Parameters.new(
      {
        limit: 50,
        start: 0
      }
    )

    assert_raises JSONAPI::Exceptions::PageParametersNotAllowed do
      OffsetPaginator.new(params)
    end
  end

  def test_offset_parse_page_params_start
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 0
      }
    )

    paginator = OffsetPaginator.new(params)

    assert_equal 5, paginator.limit
    assert_equal 0, paginator.offset
  end

  def test_offset_links_page_params_empty_results
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 0
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 0)

    assert_equal 2, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 0, links_params['last']['offset']
  end

  def test_offset_links_page_params_small_resultsets
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 0
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 3)

    assert_equal 2, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 0, links_params['last']['offset']
  end

  def test_offset_links_page_params_large_data_set_start
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 0
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['next']['limit']
    assert_equal 5, links_params['next']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 45, links_params['last']['offset']
  end

  def test_offset_links_page_params_large_data_set_before_start
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 2
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 4, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['prev']['limit']
    assert_equal 0, links_params['prev']['offset']

    assert_equal 5, links_params['next']['limit']
    assert_equal 7, links_params['next']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 45, links_params['last']['offset']
  end

  def test_offset_links_page_params_large_data_set_middle
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 27
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 4, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['prev']['limit']
    assert_equal 22, links_params['prev']['offset']

    assert_equal 5, links_params['next']['limit']
    assert_equal 32, links_params['next']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 45, links_params['last']['offset']
  end

  def test_offset_links_page_params_large_data_set_end
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 45
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['prev']['limit']
    assert_equal 40, links_params['prev']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 45, links_params['last']['offset']
  end

  def test_offset_links_page_params_large_data_set_past_end
    params = ActionController::Parameters.new(
      {
        limit: 5,
        offset: 48
      }
    )

    paginator = OffsetPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['limit']
    assert_equal 0, links_params['first']['offset']

    assert_equal 5, links_params['prev']['limit']
    assert_equal 43, links_params['prev']['offset']

    assert_equal 5, links_params['last']['limit']
    assert_equal 45, links_params['last']['offset']
  end
end
