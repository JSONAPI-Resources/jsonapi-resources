# frozen_string_literal: true
require File.expand_path('../../../test_helper', __FILE__)

class RoutesTest < ActionDispatch::IntegrationTest

  def test_routing_posts_show
    assert_routing({path: '/posts/1', method: :get},
                   {action: 'show', controller: 'posts', id: '1'})
  end

  def test_routing_posts_links_author_show
    assert_routing({path: '/posts/1/relationships/author', method: :get},
                   {controller: 'posts', action: 'show_relationship', post_id: '1', relationship: 'author'})
  end

  def test_routing_posts_links_tags_show
    assert_routing({path: '/posts/1/relationships/tags', method: :get},
                   {controller: 'posts', action: 'show_relationship', post_id: '1', relationship: 'tags'})
  end

  def test_routing_uuid
    assert_routing({path: '/pets/v1/cats/f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5', method: :get},
                   {action: 'show', controller: 'pets/v1/cats', id: 'f1a4d5f2-e77a-4d0a-acbb-ee0b98b3f6b5'})
  end

  # V1
  def test_routing_v1_posts_show
    assert_routing({path: '/api/v1/posts/1', method: :get},
                   {action: 'show', controller: 'api/v1/posts', id: '1'})
  end

  def test_routing_v1_posts_links_writer_show
    assert_routing({path: '/api/v1/posts/1/relationships/writer', method: :get},
                   {controller: 'api/v1/posts', action: 'show_relationship', post_id: '1', relationship: 'writer'})
  end

  # V2
  def test_routing_v2_posts_links_author_show
    assert_routing({path: '/api/v2/posts/1/relationships/author', method: :get},
                   {controller: 'api/v2/posts', action: 'show_relationship', post_id: '1', relationship: 'author'})
  end

  def test_routing_v2_preferences_show
    assert_routing({path: '/api/v2/preferences', method: :get},
                   {action: 'show', controller: 'api/v2/preferences'})
  end

  # V3
  def test_routing_v3_posts_show
    assert_routing({path: '/api/v3/posts/1', method: :get},
                   {action: 'show', controller: 'api/v3/posts', id: '1'})
  end

  # V4 camelCase
  def test_routing_v4_posts_show
    assert_routing({path: '/api/v4/posts/1', method: :get},
                   {action: 'show', controller: 'api/v4/posts', id: '1'})
  end

  def test_routing_v4_isoCurrencies_resources
    assert_routing({path: '/api/v4/isoCurrencies/USD', method: :get},
                   {action: 'show', controller: 'api/v4/iso_currencies', id: 'USD'})
  end

  def test_routing_v4_expenseEntries_resources
    assert_routing({path: '/api/v4/expenseEntries/1', method: :get},
                   {action: 'show', controller: 'api/v4/expense_entries', id: '1'})

    assert_routing({path: '/api/v4/expenseEntries/1/relationships/isoCurrency', method: :get},
                   {controller: 'api/v4/expense_entries', action: 'show_relationship', expense_entry_id: '1', relationship: 'iso_currency'})
  end

  # V5 dasherized
  def test_routing_v5_posts_show
    assert_routing({path: '/api/v5/posts/1', method: :get},
                   {action: 'show', controller: 'api/v5/posts', id: '1'})
  end

  def test_routing_v5_isoCurrencies_resources
    assert_routing({path: '/api/v5/iso-currencies/USD', method: :get},
                   {action: 'show', controller: 'api/v5/iso_currencies', id: 'USD'})
  end

  def test_routing_v5_expenseEntries_resources
    assert_routing({path: '/api/v5/expense-entries/1', method: :get},
                   {action: 'show', controller: 'api/v5/expense_entries', id: '1'})

    assert_routing({path: '/api/v5/expense-entries/1/relationships/iso-currency', method: :get},
                   {controller: 'api/v5/expense_entries', action: 'show_relationship', expense_entry_id: '1', relationship: 'iso_currency'})
  end

  def test_routing_authors_show
    assert_routing({path: '/api/v5/authors/1', method: :get},
                   {action: 'show', controller: 'api/v5/authors', id: '1'})
  end

  def test_routing_list_items_index
    assert_routing({path: '/list_items', method: :get},
                   {controller: 'list_items', action: 'index'})
  end

  def test_routing_list_related_items
    assert_routing({path: '/lists/1/items', method: :get},
                   {controller: 'list_items', action: 'index_related_resources', relationship: 'items', list_id: '1', source: 'lists'})
  end

  def test_list_items_route_helper_name
    assert_equal(list_items_path, '/list_items')
  end

  #primary_key
  def test_routing_primary_key_jsonapi_resources
    assert_routing({path: '/iso_currencies/USD', method: :get},
                   {action: 'show', controller: 'iso_currencies', id: 'USD'})
  end

end
