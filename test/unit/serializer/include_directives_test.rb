require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class IncludeDirectivesTest < ActiveSupport::TestCase

  def test_one_level_one_include
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {},
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_one_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'comments', 'expense_entries']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {},
            include_in_join: true
          },
          comments: {
            include: true,
            include_related: {},
            include_in_join: true
          },
          expense_entries: {
            include: true,
            include_related: {},
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_multiple_level_multiple_includes
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'posts.comments', 'comments', 'expense_entries']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {
              comments: {
                include: true,
                include_related: {},
                include_in_join: true
              }
            },
            include_in_join: true
          },
          comments: {
            include: true,
            include_related: {},
            include_in_join: true
          },
          expense_entries: {
            include: true,
            include_related: {},
            include_in_join: true
          }
        }
      },
      directives)
  end


  def test_two_levels_include_full_path
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {
              comments: {
                include: true,
                include_related: {},
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_two_levels_include_full_path_redundant
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts', 'posts.comments']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {
              comments: {
                include: true,
                include_related: {},
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  def test_three_levels_include_full
    directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags']).instance_variable_get(:@include_directives_hash)

    assert_hash_equals(
      {
        include_related: {
          posts: {
            include: true,
            include_related: {
              comments: {
                include: true,
                include_related: {
                  tags: {
                    include: true,
                    include_related: {},
                    include_in_join: true
                  }
                },
                include_in_join: true
              }
            },
            include_in_join: true
          }
        }
      },
      directives)
  end

  # def test_three_levels_include_full_model_includes
  #   directives = JSONAPI::IncludeDirectives.new(PersonResource, ['posts.comments.tags'])
  #   assert_array_equals([{:posts=>[{:comments=>[:tags]}]}], directives.model_includes)
  # end
  #
  def test_invalid_includes_1
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['../../../../']).instance_variable_get(:@include_directives_hash)
    end
  end

  def test_invalid_includes_2
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['posts./sdaa./........']).instance_variable_get(:@include_directives_hash)
    end
  end

  def test_invalid_includes_3
    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::IncludeDirectives.new(PersonResource, ['invalid../../../../']).instance_variable_get(:@include_directives_hash)
    end
  end
end
