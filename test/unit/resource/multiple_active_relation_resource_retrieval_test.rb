require File.expand_path('../../../test_helper', __FILE__)

module VX
end

class MultipleActiveRelationResourceTest < ActiveSupport::TestCase
  def setup
  end

  def teardown
    teardown_test_constant(::VX, :BaseResource)
    teardown_test_constant(::VX, :DuplicateSubBaseResource)
    teardown_test_constant(::VX, :InvalidSubBaseResource)
    teardown_test_constant(::VX, :ValidCustomBaseResource)
  end

  def teardown_test_constant(namespace, constant_name)
    return unless namespace.const_defined?(constant_name)
    namespace.send(:remove_const, constant_name)
  rescue NameError
  end

  def test_correct_resource_retrieval_strategy
    expected = 'JSONAPI::ActiveRelationRetrieval'
    default = JSONAPI.configuration.default_resource_retrieval_strategy
    assert_equal expected, default
    assert_nil JSONAPI::Resource._resource_retrieval_strategy_loaded

    expected = 'JSONAPI::ActiveRelationRetrieval'
    assert_silent do
      ::VX.module_eval <<~MODULE
        class BaseResource < JSONAPI::Resource
          abstract
        end
      MODULE
    end
    assert_equal expected, VX::BaseResource._resource_retrieval_strategy_loaded

    strategy = 'JSONAPI::ActiveRelationRetrieval'
    expected = 'JSONAPI::ActiveRelationRetrieval'
    assert_output nil, "Resource retrieval strategy #{expected} already loaded for VX::DuplicateSubBaseResource\n" do
      ::VX.module_eval <<~MODULE
        class DuplicateSubBaseResource < JSONAPI::Resource
          resource_retrieval_strategy '#{strategy}'
          abstract
        end
      MODULE
    end
    assert_equal expected, VX::DuplicateSubBaseResource._resource_retrieval_strategy_loaded

    strategy = 'JSONAPI::ActiveRelationRetrievalV10'
    expected = "Resource retrieval strategy #{default} already loaded for VX::InvalidSubBaseResource. Cannot load #{strategy}"
    ex = assert_raises ArgumentError do
      ::VX.module_eval <<~MODULE
        class InvalidSubBaseResource < JSONAPI::Resource
          resource_retrieval_strategy '#{strategy}'
          abstract
        end
      MODULE
    end
    assert_equal expected, ex.message

    strategy = 'JSONAPI::ActiveRelationRetrievalV10'
    expected = 'JSONAPI::ActiveRelationRetrievalV10'
    assert_silent do
      ::VX.module_eval <<~MODULE
        class ValidCustomBaseResource
          include JSONAPI::ResourceCommon
          root_resource
          abstract
          immutable
          resource_retrieval_strategy '#{strategy}'
        end
      MODULE
    end
    assert_equal expected, VX::ValidCustomBaseResource._resource_retrieval_strategy_loaded
  end
end
