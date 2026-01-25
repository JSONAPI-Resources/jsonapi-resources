# frozen_string_literal: true

require File.expand_path('../../test_helper', __dir__)
require 'jsonapi-resources'

class PathTest < ActiveSupport::TestCase
  def test_one_relationship
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments')

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_equal Api::V1::PostResource._relationship(:comments), path.segments[0].relationship
  end

  def test_one_field
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'title')

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Field, path.segments[0], 'should be a PathSegment::Field'
    assert_equal 'title', path.segments[0].field_name
  end

  def test_two_relationships
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author')

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[1], 'should be a PathSegment::Relationship'
    assert_equal Api::V1::PostResource._relationship(:comments), path.segments[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.segments[1].relationship
  end

  def test_two_relationships_and_field
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author.name')

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[1], 'should be a PathSegment::Relationship'
    assert_kind_of JSONAPI::PathSegment::Field, path.segments[2], 'should be a PathSegment::Field'

    assert_equal Api::V1::PostResource._relationship(:comments), path.segments[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.segments[1].relationship
    assert_equal 'name', path.segments[2].field_name

    assert_equal 2, path.relationship_segments.length
  end

  def test_two_relationships_and_parse_fields_false_raises_with_field
    assert_raises JSONAPI::Exceptions::InvalidRelationship do
      path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource,
                               path_string: 'comments.author.name',
                               parse_fields: false)
    end
  end

  def test_ensure_default_field_false
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author',
                             ensure_default_field: false)

    assert_kind_of Array, path.segments
    assert_equal 2, path.segments.length
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[1], 'should be a PathSegment::Relationship'

    assert_equal Api::V1::PostResource._relationship(:comments), path.segments[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.segments[1].relationship
  end

  def test_ensure_default_field_true
    path = JSONAPI::Path.new(resource_klass: Api::V1::PostResource, path_string: 'comments.author',
                             ensure_default_field: true)

    assert_kind_of Array, path.segments
    assert_equal 3, path.segments.length
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[1], 'should be a PathSegment::Relationship'

    assert_equal Api::V1::PostResource._relationship(:comments), path.segments[0].relationship
    assert_equal Api::V1::CommentResource._relationship(:author), path.segments[1].relationship
  end

  def test_polymorphic_path
    path = JSONAPI::Path.new(resource_klass: PictureResource, path_string: :imageable)

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_equal PictureResource._relationship(:imageable), path.segments[0].relationship
    refute_predicate path.segments[0], :path_specified_resource_klass?,
                     'should note that the resource klass was not specified'
  end

  def test_polymorphic_path_with_resource_type
    path = JSONAPI::Path.new(resource_klass: PictureResource, path_string: 'imageable#documents')

    assert_kind_of Array, path.segments
    assert_kind_of JSONAPI::PathSegment::Relationship, path.segments[0], 'should be a PathSegment::Relationship'
    assert_equal PictureResource._relationship(:imageable), path.segments[0].relationship
    assert_equal DocumentResource, path.segments[0].resource_klass, 'should return the specified resource klass'
    assert_predicate path.segments[0], :path_specified_resource_klass?,
                     'should note that the resource klass was specified'
  end

  def test_polymorphic_path_with_wrong_resource_type
    assert_raises JSONAPI::Exceptions::InvalidRelationship do
      JSONAPI::Path.new(resource_klass: PictureResource, path_string: 'imageable#docs')
    end
  end

  def test_raises_when_field_is_specified_if_not_expected
    assert JSONAPI::Path.new(resource_klass: PictureResource, path_string: 'comments.author.name', parse_fields: true)

    assert_raises JSONAPI::Exceptions::InvalidRelationship do
      JSONAPI::Path.new(resource_klass: PictureResource, path_string: 'comments.author.name', parse_fields: false)
    end
  end
end
