# frozen_string_literal: true

require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class PagedPaginatorTest < ActiveSupport::TestCase
  def test_paged_default_page_params
    params = ActionController::Parameters.new(
      {}
    )

    paginator = PagedPaginator.new(params)

    assert_equal JSONAPI.configuration.default_page_size, paginator.size
    assert_equal 1, paginator.number
  end

  def test_paged_parse_page_params_default_page
    params = ActionController::Parameters.new(
      {
        size: 20
      }
    )

    paginator = PagedPaginator.new(params)

    assert_equal 20, paginator.size
    assert_equal 1, paginator.number
  end

  def test_paged_parse_page_params
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 7
      }
    )

    paginator = PagedPaginator.new(params)

    assert_equal 5, paginator.size
    assert_equal 7, paginator.number
  end

  def test_paged_parse_page_params_size_too_large
    params = ActionController::Parameters.new(
      {
        size: 50,
        number: 1
      }
    )

    assert_raises JSONAPI::Exceptions::InvalidPageValue do
      PagedPaginator.new(params)
    end
  end

  def test_paged_parse_page_params_not_allowed
    params = ActionController::Parameters.new(
      {
        size: 50,
        start: 1
      }
    )

    assert_raises JSONAPI::Exceptions::PageParametersNotAllowed do
      PagedPaginator.new(params)
    end
  end

  def test_paged_parse_page_params_start
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 1
      }
    )

    paginator = PagedPaginator.new(params)

    assert_equal 5, paginator.size
    assert_equal 1, paginator.number
  end

  def test_paged_links_page_params_empty_results
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 1
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 0)

    assert_equal 2, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 1, links_params['last']['number']
  end

  def test_paged_links_page_params_small_resultsets
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 1
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 3)

    assert_equal 2, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 1, links_params['last']['number']
  end

  def test_paged_links_page_params_large_data_set_start_full_pages
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 1
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['next']['size']
    assert_equal 2, links_params['next']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 10, links_params['last']['number']
  end

  def test_paged_links_page_params_large_data_set_start_partial_last
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 1
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 51)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['next']['size']
    assert_equal 2, links_params['next']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 11, links_params['last']['number']
  end

  def test_paged_links_page_params_large_data_set_middle
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 4
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 4, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['prev']['size']
    assert_equal 3, links_params['prev']['number']

    assert_equal 5, links_params['next']['size']
    assert_equal 5, links_params['next']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 10, links_params['last']['number']
  end

  def test_paged_links_page_params_large_data_set_end
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 10
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['prev']['size']
    assert_equal 9, links_params['prev']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 10, links_params['last']['number']
  end

  def test_paged_links_page_params_large_data_set_past_end
    params = ActionController::Parameters.new(
      {
        size: 5,
        number: 11
      }
    )

    paginator = PagedPaginator.new(params)
    links_params = paginator.links_page_params(record_count: 50)

    assert_equal 3, links_params.size

    assert_equal 5, links_params['first']['size']
    assert_equal 1, links_params['first']['number']

    assert_equal 5, links_params['prev']['size']
    assert_equal 10, links_params['prev']['number']

    assert_equal 5, links_params['last']['size']
    assert_equal 10, links_params['last']['number']
  end
end
