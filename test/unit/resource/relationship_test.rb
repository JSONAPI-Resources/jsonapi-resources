require File.expand_path('../../../test_helper', __FILE__)

class LambdaBlogPostsResource < JSONAPI::Resource
  model_name 'Post'

  has_one :author, allow_include: -> (context) { context[:admin] }
  has_many :comments, allow_include: -> (context) { context[:admin] }
end

class CallableBlogPostsResource < JSONAPI::Resource
  model_name 'Post'

  has_one :author, allow_include: :is_admin
  has_many :comments, allow_include: :is_admin

  def self.is_admin(context)
    context[:admin]
  end
end

class HasOneRelationshipTest < ActiveSupport::TestCase

  def test_polymorphic_type
    relationship = JSONAPI::Relationship::ToOne.new("imageable",
      polymorphic: true,
      parent_resource: CallableBlogPostsResource
    )
    assert_equal(relationship.polymorphic_type, "imageable_type")
  end

  def test_allow_include_not_set_defaults_to_config_to_one
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship = JSONAPI::Relationship::ToOne.new("foo")
    assert(relationship.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    relationship = JSONAPI::Relationship::ToOne.new("foo")
    refute(relationship.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_not_set_defaults_to_config_to_many
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_many = true
    relationship = JSONAPI::Relationship::ToMany.new("foobar")
    assert(relationship.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    relationship = JSONAPI::Relationship::ToOne.new("foobar")
    refute(relationship.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_overrides_to_config_to_one
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship1 = JSONAPI::Relationship::ToOne.new("foo1", allow_include: false)
    relationship2 = JSONAPI::Relationship::ToOne.new("foo2", allow_include: true)
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_overrides_to_config_to_many
    original_config = JSONAPI.configuration.dup

    JSONAPI.configuration.default_allow_include_to_one = true
    relationship1 = JSONAPI::Relationship::ToMany.new("foobar1", allow_include: false)
    relationship2 = JSONAPI::Relationship::ToMany.new("foobar2", allow_include: true)
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

    JSONAPI.configuration.default_allow_include_to_one = false
    refute(relationship1.allow_include?)
    assert(relationship2.allow_include?)

  ensure
    JSONAPI.configuration = original_config
  end

  def test_allow_include_set_by_lambda
    assert LambdaBlogPostsResource._relationship(:author).allow_include?(admin: true)
    refute LambdaBlogPostsResource._relationship(:author).allow_include?(admin: false)

    assert LambdaBlogPostsResource._relationship(:comments).allow_include?(admin: true)
    refute LambdaBlogPostsResource._relationship(:comments).allow_include?(admin: false)
  end

  def test_allow_include_set_by_callable
    assert CallableBlogPostsResource._relationship(:author).allow_include?(admin: true)
    refute CallableBlogPostsResource._relationship(:author).allow_include?(admin: false)

    assert CallableBlogPostsResource._relationship(:comments).allow_include?(admin: true)
    refute CallableBlogPostsResource._relationship(:comments).allow_include?(admin: false)
  end

  def test_exclude_links_on_relationship
    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :default
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")
    assert relationship.exclude_link?(:related)
    assert relationship.exclude_link?("related")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: "none"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: "default"
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: [:self]
    assert_equal [:self], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: ["self", :related]
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: []
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    assert_raises do
      JSONAPI::Relationship::ToOne.new "foo", :self
    end
  end

  def test_global_exclude_links_configuration_on_relationship
    JSONAPI.configuration.default_exclude_links = :none
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = :default
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")
    assert relationship.exclude_link?(:related)
    assert relationship.exclude_link?("related")

    JSONAPI.configuration.default_exclude_links = "none"
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = "default"
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = :none
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = [:self]
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [:self], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = :none
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = ["self", :related]
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [:self, :related], relationship._exclude_links
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")

    JSONAPI.configuration.default_exclude_links = []
    relationship = JSONAPI::Relationship::ToOne.new "foo"
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")

    assert_raises do
      JSONAPI.configuration.default_exclude_links = :self
      JSONAPI::Relationship::ToOne.new "foo"
    end

    # Test if the relationships will override the the global configuration
    JSONAPI.configuration.default_exclude_links = :default
    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: :none
    assert_equal [], relationship._exclude_links
    refute relationship.exclude_link?(:self)
    refute relationship.exclude_link?("self")
    refute relationship.exclude_link?(:related)
    refute relationship.exclude_link?("related")

    JSONAPI.configuration.default_exclude_links = :default
    relationship = JSONAPI::Relationship::ToOne.new "foo", exclude_links: [:self]
    assert_equal [:self], relationship._exclude_links
    refute relationship.exclude_link?(:related)
    refute relationship.exclude_link?("related")
    assert relationship.exclude_link?(:self)
    assert relationship.exclude_link?("self")
  ensure
    JSONAPI.configuration.default_exclude_links = :none
  end


end
