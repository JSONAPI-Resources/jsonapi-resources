# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ReflectCreateAndDeleteBenchmark < IntegrationBenchmark
  def setup
    $test_user = Person.find(1)
  end

  def create_and_delete_comments
    post '/posts/15/relationships/comments', params:
      {
        'data' => [
          { type: 'comments', id: 1 },
          { type: 'comments', id: 2 },
          { type: 'comments', id: 3 }
        ]
      }.to_json,
                                             headers: {
                                               'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE,
                                               'Accept' => JSONAPI::MEDIA_TYPE
                                             }

    assert_response :no_content
    post_object = Post.find(15)

    assert_equal 3, post_object.comments.collect { |comment| comment.id }.length

    delete '/posts/15/relationships/comments', params:
      {
        'data' => [
          { type: 'comments', id: 1 },
          { type: 'comments', id: 2 },
          { type: 'comments', id: 3 }
        ]
      }.to_json,
                                               headers: {
                                                 'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE,
                                                 'Accept' => JSONAPI::MEDIA_TYPE
                                               }

    assert_response :no_content
    post_object = Post.find(15)

    assert_equal 0, post_object.comments.collect { |comment| comment.id }.length
  end

  # ToDo: Cleanup fixtures and session so benchmarks are consistent without an order dependence.

  # def bench_create_and_delete
  #   reflect = ENV['REFLECT']
  #   if reflect
  #     puts "relationship reflection on"
  #     JSONAPI.configuration.use_relationship_reflection = true
  #   else
  #     puts "relationship reflection off"
  #     JSONAPI.configuration.use_relationship_reflection = false
  #   end
  #
  #   100.times do
  #     create_and_delete_comments
  #   end
  #
  # ensure
  #   JSONAPI.configuration.use_relationship_reflection = false
  # end

  def bench_create_and_delete_comments_reflection_on
    JSONAPI.configuration.use_relationship_reflection = true

    100.times do
      create_and_delete_comments
    end
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end

  def bench_create_and_delete_comments_reflection_off
    JSONAPI.configuration.use_relationship_reflection = false

    100.times do
      create_and_delete_comments
    end
  ensure
    JSONAPI.configuration.use_relationship_reflection = false
  end
end
