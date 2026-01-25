# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class ValueMatchersTest < ActionController::TestCase
  def test_matches_value_any
    assert(matches_value?(:any, 'a'))
    assert(matches_value?(:any, nil))
  end

  def test_matches_value_not_nil
    assert(matches_value?(:not_nil, 'a'))
    refute(matches_value?(:not_nil, nil))
  end

  def test_matches_value_array
    assert(matches_value?(['a', 'b', 'c'], ['b', 'c', 'a']))
    assert(matches_value?(['a', 'b', 'c'], ['a', 'b', 'c']))
    refute(matches_value?(['a', 'b', 'c'], ['a', 'a']))
    refute(matches_value?(['a', 'b', 'c'], ['a', 'b', 'd']))

    assert(matches_value?(['a', 'b', :any], ['a', 'b', 'c']))
    assert(matches_value?(['a', 'b', :not_nil], ['a', 'b', 'c']))
    refute(matches_value?(['a', 'b', :not_nil], ['a', 'b', nil]))
  end

  def test_matches_value_hash
    assert(matches_value?({ a: 'a', b: 'b', c: 'c' }, { a: 'a', b: 'b', c: 'c' }))
    assert(matches_value?({ a: 'a', b: 'b', c: 'c' }, { b: 'b', c: 'c', a: 'a' }))
    refute(matches_value?({ a: 'a', b: 'b', c: 'c' }, { b: 'a', c: 'c', a: 'b' }))

    assert(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: 'e' } }, { b: 'b', c: { a: 'a', d: 'e' }, a: 'a' }))
    refute(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: 'd' } }, { b: 'b', c: { a: 'a', d: 'e' }, a: 'a' }))

    assert(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: { a: :not_nil } } },
                          { b: 'b', c: { a: 'a', d: { a: 'b' } }, a: 'a' }))
    refute(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: { a: :not_nil } } },
                          { b: 'b', c: { a: 'a', d: { a: nil } }, a: 'a' }))

    assert(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: { a: :any } } },
                          { b: 'b', c: { a: 'a', d: { a: 'b' } }, a: 'a' }))
    assert(matches_value?({ a: 'a', b: 'b', c: { a: 'a', d: { a: :any } } },
                          { b: 'b', c: { a: 'a', d: { a: nil } }, a: 'a' }))
  end
end
