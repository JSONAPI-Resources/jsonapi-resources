# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class ReflectUpdateRelationshipsBenchmark < IntegrationBenchmark
  def setup
    $test_user = Person.find(1)
  end

  def replace_tags
    put '/posts/15/relationships/tags', params:
      {
        'data' => [{ type: 'tags', id: 11 }, { type: 'tags', id: 3 }, { type: 'tags', id: 12 }, { type: 'tags', id: 13 }, { type: 'tags', id: 14 }]
      }.to_json,
                                        headers: {
                                          'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE,
                                          'Accept' => JSONAPI::MEDIA_TYPE
                                        }

    assert_response :no_content
    post_object = Post.find(15)

    assert_equal 5, post_object.tags.collect { |tag| tag.id }.length

    put '/posts/15/relationships/tags', params:
      {
        'data' => [{ type: 'tags', id: 2 }, { type: 'tags', id: 3 }, { type: 'tags', id: 4 }]
      }.to_json,
                                        headers: {
                                          'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE,
                                          'Accept' => JSONAPI::MEDIA_TYPE
                                        }

    assert_response :no_content
    post_object = Post.find(15)

    assert_equal 3, post_object.tags.collect { |tag| tag.id }.length
  end

  # ToDo: Cleanup fixtures and session so benchmarks are consistent without an order dependence.

  # def bench_update_relationship
  #   reflect = ENV['REFLECT']
  #   if reflect
  #     puts "relationship reflection on"
  #   else
  #     puts "relationship reflection off"
  #   end
  #   JSONAPI.configuration.use_relationship_reflection = reflect
  #
  #   100.times do
  #     replace_tags
  #   end
  # ensure
  #   JSONAPI.configuration.use_relationship_reflection = false
  # end

  def bench_update_relationship_reflection_on
    JSONAPI.configuration.use_relationship_reflection = true

    100.times do
      replace_tags
    end
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def bench_update_relationship_reflection_off
    JSONAPI.configuration.use_relationship_reflection = false

    100.times do
      replace_tags
    end
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end
end
