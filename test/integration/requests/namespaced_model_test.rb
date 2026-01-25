# frozen_string_literal: true

require File.expand_path('../../../test_helper', __FILE__)

class NamedspacedModelTest < ActionDispatch::IntegrationTest
  def setup
    JSONAPI.configuration.json_key_format = :underscored_key
  end

  def test_get_flat_posts
    assert_cacheable_jsonapi_get '/flat_posts'
    assert_equal "flat_posts", json_response["data"].first["type"]
  end
end
