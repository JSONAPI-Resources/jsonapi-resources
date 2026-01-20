require File.expand_path('../../../test_helper', __FILE__)
require 'jsonapi-resources'

class JoinTreeTest < ActiveSupport::TestCase

  def db_true
    ActiveRecord::Base.connection.quoted_true
  end

  def test_no_added_joins
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource)

    records = PostResource.records({})
    records = join_manager.join(records, {})
    assert_equal 'SELECT "posts".* FROM "posts"', records.to_sql

    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
  end

  def test_add_single_join
    filters = {'tags' => ['1']}
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource, filters: filters)
    records = PostResource.records({})
    records = join_manager.join(records, {})
    assert_equal 'SELECT "posts".* FROM "posts" LEFT OUTER JOIN "posts_tags" ON "posts_tags"."post_id" = "posts"."id" LEFT OUTER JOIN "tags" ON "tags"."id" = "posts_tags"."tag_id"', records.to_sql
    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(PostResource._relationship(:tags)))
  end

  def test_add_single_sort_join
    sort_criteria = [{field: 'tags.name', direction: :desc}]
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource, sort_criteria: sort_criteria)
    records = PostResource.records({})
    records = join_manager.join(records, {})

    assert_equal 'SELECT "posts".* FROM "posts" LEFT OUTER JOIN "posts_tags" ON "posts_tags"."post_id" = "posts"."id" LEFT OUTER JOIN "tags" ON "tags"."id" = "posts_tags"."tag_id"', records.to_sql
    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(PostResource._relationship(:tags)))
  end

  def test_add_single_sort_and_filter_join
    filters = {'tags' => ['1']}
    sort_criteria = [{field: 'tags.name', direction: :desc}]
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource, sort_criteria: sort_criteria, filters: filters)
    records = PostResource.records({})
    records = join_manager.join(records, {})
    assert_equal 'SELECT "posts".* FROM "posts" LEFT OUTER JOIN "posts_tags" ON "posts_tags"."post_id" = "posts"."id" LEFT OUTER JOIN "tags" ON "tags"."id" = "posts_tags"."tag_id"', records.to_sql
    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(PostResource._relationship(:tags)))
  end

  def test_add_sibling_joins
    filters = {
        'tags' => ['1'],
        'author' => ['1']
    }

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource, filters: filters)
    records = PostResource.records({})
    records = join_manager.join(records, {})

    assert_equal 'SELECT "posts".* FROM "posts" LEFT OUTER JOIN "posts_tags" ON "posts_tags"."post_id" = "posts"."id" LEFT OUTER JOIN "tags" ON "tags"."id" = "posts_tags"."tag_id" LEFT OUTER JOIN "people" ON "people"."id" = "posts"."author_id"', records.to_sql
    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(PostResource._relationship(:tags)))
    assert_hash_equals({alias: 'people', join_type: :left}, join_manager.join_details_by_relationship(PostResource._relationship(:author)))
  end


  def test_add_joins_source_relationship
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource,
                                                                          source_relationship: PostResource._relationship(:comments))
    records = PostResource.records({})
    records = join_manager.join(records, {})

    assert_equal 'SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id"', records.to_sql
    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.source_join_details)
  end


  def test_add_joins_source_relationship_with_custom_apply
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: Api::V10::PostResource,
                                                                          source_relationship: Api::V10::PostResource._relationship(:comments))
    records = Api::V10::PostResource.records({})
    records = join_manager.join(records, {})

    sql = 'SELECT "posts".* FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" WHERE "comments"."approved" = ' + db_true

    assert_equal sql, records.to_sql

    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.source_join_details)
  end

  def test_add_nested_scoped_joins
    filters = {
        'comments.author' => ['1'],
        'comments.tags' => ['1'],
        'author' => ['1']
    }

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: Api::V10::PostResource, filters: filters)
    records = Api::V10::PostResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:comments)))
    assert_hash_equals({alias: 'authors_comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:author)))
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:tags)))
    assert_hash_equals({alias: 'people', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:author)))

    # Now test with different order for the filters
    filters = {
        'author' => ['1'],
        'comments.author' => ['1'],
        'comments.tags' => ['1']
    }

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: Api::V10::PostResource, filters: filters)
    records = Api::V10::PostResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:comments)))
    assert_hash_equals({alias: 'authors_comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:author)))
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:tags)))
    assert_hash_equals({alias: 'people', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:author)))
  end

  def test_add_nested_joins_with_fields
    filters = {
        'comments.author.name' => ['1'],
        'comments.tags.id' => ['1'],
        'author.foo' => ['1']
    }

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: Api::V10::PostResource, filters: filters)
    records = Api::V10::PostResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'posts', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:comments)))
    assert_hash_equals({alias: 'authors_comments', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:author)))
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:tags)))
    assert_hash_equals({alias: 'people', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:author)))
  end

  def test_add_joins_with_sub_relationship
    relationships = %w(author author.comments tags)

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: Api::V10::PostResource, relationships: relationships,
                                                                          source_relationship: Api::V10::PostResource._relationship(:comments))
    records = Api::V10::PostResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.source_join_details)
    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.join_details_by_relationship(Api::V10::PostResource._relationship(:comments)))
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::CommentResource._relationship(:tags)))
    assert_hash_equals({alias: 'comments_people', join_type: :left}, join_manager.join_details_by_relationship(Api::V10::PersonResource._relationship(:comments)))
  end

  def test_add_joins_with_sub_relationship_and_filters
    filters = {
        'author.name' => ['1'],
        'author.comments.name' => ['Foo']
    }

    relationships = %w(author author.comments tags)

    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PostResource,
                                                                          filters: filters,
                                                                          relationships: relationships,
                                                                          source_relationship: PostResource._relationship(:comments))
    records = PostResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.source_join_details)
    assert_hash_equals({alias: 'comments', join_type: :inner}, join_manager.join_details_by_relationship(PostResource._relationship(:comments)))
    assert_hash_equals({alias: 'people', join_type: :left}, join_manager.join_details_by_relationship(CommentResource._relationship(:author)))
    assert_hash_equals({alias: 'tags', join_type: :left}, join_manager.join_details_by_relationship(CommentResource._relationship(:tags)))
    assert_hash_equals({alias: 'comments_people', join_type: :left}, join_manager.join_details_by_relationship(PersonResource._relationship(:comments)))
  end

  def test_polymorphic_join_belongs_to_just_source
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PictureResource,
                                                                          source_relationship: PictureResource._relationship(:imageable))

    records = PictureResource.records({})
    records = join_manager.join(records, {})

    # assert_equal 'SELECT "pictures".* FROM "pictures" LEFT OUTER JOIN "products" ON "products"."id" = "pictures"."imageable_id" AND "pictures"."imageable_type" = \'Product\' LEFT OUTER JOIN "documents" ON "documents"."id" = "pictures"."imageable_id" AND "pictures"."imageable_type" = \'Document\'', records.to_sql
    assert_hash_equals({alias: 'products', join_type: :left}, join_manager.source_join_details('products'))
    assert_hash_equals({alias: 'documents', join_type: :left}, join_manager.source_join_details('documents'))
    assert_hash_equals({alias: 'products', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'products'))
    assert_hash_equals({alias: 'documents', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'documents'))
  end

  def test_polymorphic_join_belongs_to_filter
    filters = {'imageable' => ['Foo']}
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PictureResource, filters: filters)

    records = PictureResource.records({})
    records = join_manager.join(records, {})

    # assert_equal 'SELECT "pictures".* FROM "pictures" LEFT OUTER JOIN "products" ON "products"."id" = "pictures"."imageable_id" AND "pictures"."imageable_type" = \'Product\' LEFT OUTER JOIN "documents" ON "documents"."id" = "pictures"."imageable_id" AND "pictures"."imageable_type" = \'Document\'', records.to_sql
    assert_hash_equals({alias: 'pictures', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'products', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'products'))
    assert_hash_equals({alias: 'documents', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'documents'))
  end

  def test_polymorphic_join_belongs_to_filter_on_resource
    filters = {
        'imageable#documents.name' => ['foo']
    }

    relationships = %w(imageable file_properties)
    join_manager = JSONAPI::ActiveRelation::JoinManager.new(resource_klass: PictureResource,
                                                                          filters: filters,
                                                                          relationships: relationships)

    records = PictureResource.records({})
    records = join_manager.join(records, {})

    assert_hash_equals({alias: 'pictures', join_type: :root}, join_manager.source_join_details)
    assert_hash_equals({alias: 'products', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'products'))
    assert_hash_equals({alias: 'documents', join_type: :left}, join_manager.join_details_by_polymorphic_relationship(PictureResource._relationship(:imageable), 'documents'))
    assert_hash_equals({alias: 'file_properties', join_type: :left}, join_manager.join_details_by_relationship(PictureResource._relationship(:file_properties)))
  end
end
