# frozen_string_literal: true
require File.expand_path("../../test_helper", __FILE__)

class StiFieldsTest < ActionDispatch::IntegrationTest
  def test_index_fields_when_resource_does_not_match_relationship
    get "/posts", params: {
                    filter: { id: "1,2" },
                    include: "author",
                    fields: { posts: "author", people: "email" } },
                  headers: { 'Accept' => JSONAPI::MEDIA_TYPE }
    assert_response :success
    assert_equal 2, json_response["data"].size
    assert json_response["data"][0]["relationships"].key?("author")
    assert json_response["included"][0]["attributes"].keys == ["email"]
  end

  def test_fields_for_parent_class
    get "/firms", params: { fields: { companies: "name" } }, headers: {
      'Accept' => JSONAPI::MEDIA_TYPE
    }
    assert_equal json_response["data"][0]["attributes"].keys, ["name"]
  end
end
