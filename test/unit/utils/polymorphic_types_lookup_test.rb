require File.expand_path('../../../test_helper', __FILE__)

class PolymorphicTypesLookupTest < ActiveSupport::TestCase
  def setup
    JSONAPI::Utils::PolymorphicTypesLookup.polymorphic_types_lookup_clear!
  end

  def test_build_polymorphic_types_lookup_from_object_space
    expected = {
      :imageable=>["product", "document"]
    }
    actual = JSONAPI::Utils::PolymorphicTypesLookup.build_polymorphic_types_lookup_from_object_space
    actual_keys = actual.keys.sort
    assert_equal(actual_keys, expected.keys.sort)
    actual_keys.each do |actual_key|
      actual_values = actual[actual_key].sort
      expected_values = expected[actual_key].sort
      assert_equal(actual_values, expected_values)
    end
  end

  def test_build_polymorphic_types_lookup_from_descendants
    expected = {
      :imageable=>["document", "product"]
    }
    actual = JSONAPI::Utils::PolymorphicTypesLookup.build_polymorphic_types_lookup_from_descendants
    actual_keys = actual.keys.sort
    assert_equal(actual_keys, expected.keys.sort)
    actual_keys.each do |actual_key|
      actual_values = actual[actual_key].sort
      expected_values = expected[actual_key].sort
      assert_equal(actual_values, expected_values)
    end
  end
end
