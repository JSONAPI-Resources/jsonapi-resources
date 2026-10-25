require File.expand_path('../../test_helper', __FILE__)

class FunctionalHelpersTest < ActionController::TestCase

  def test_normalize_linkage_order_sorts_to_many_linkage_in_data_and_included
    json = {
      'data' => [
        { 'type' => 'books', 'id' => '1', 'relationships' => {
          'book_comments' => { 'data' => [{ 'type' => 'book_comments', 'id' => '9' },
                                          { 'type' => 'book_comments', 'id' => '2' }] } } }
      ],
      'included' => [
        { 'type' => 'people', 'id' => '3', 'relationships' => {
          'comments' => { 'data' => [{ 'type' => 'comments', 'id' => '5' },
                                     { 'type' => 'comments', 'id' => '4' }] } } }
      ]
    }

    normalized = normalize_linkage_order(json)

    assert_equal %w[2 9], normalized['data'][0]['relationships']['book_comments']['data'].map { |r| r['id'] }
    assert_equal %w[4 5], normalized['included'][0]['relationships']['comments']['data'].map { |r| r['id'] }
  end

  def test_normalize_linkage_order_leaves_everything_else_unchanged
    assert_nil normalize_linkage_order(nil)

    json = {
      'data' => [
        { 'type' => 'books', 'id' => '2', 'relationships' => {
          'author' => { 'data' => { 'type' => 'people', 'id' => '7' } },
          'tags' => { 'links' => { 'related' => '/books/2/tags' } } } },
        { 'type' => 'books', 'id' => '1' }
      ]
    }

    normalized = normalize_linkage_order(json)

    assert_equal %w[2 1], normalized['data'].map { |r| r['id'] }
    assert_equal({ 'type' => 'people', 'id' => '7' }, normalized['data'][0]['relationships']['author']['data'])
    assert_equal({ 'links' => { 'related' => '/books/2/tags' } }, normalized['data'][0]['relationships']['tags'])
  end
end
