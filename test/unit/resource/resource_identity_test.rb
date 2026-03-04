require File.expand_path('../../../test_helper', __FILE__)
require 'memory_profiler'

class ResourceIdentity < ActiveSupport::TestCase

  def test_can_generate_a_consistent_hash_for_comparison
    rid = JSONAPI::ResourceIdentity.new(PostResource, 12)
    assert_equal(rid.hash, [PostResource, 12].hash)
  end

  def test_equality
    rid = JSONAPI::ResourceIdentity.new(PostResource, 12)
    rid2 = JSONAPI::ResourceIdentity.new(PostResource, 12)
    assert_equal(rid, rid2) # uses == internally
    assert rid.eql?(rid2)
  end

  def test_inequality
    rid = JSONAPI::ResourceIdentity.new(PostResource, 12)
    rid2 = JSONAPI::ResourceIdentity.new(PostResource, 13)
    refute_equal(rid, rid2)
  end

  def test_sorting_by_resource_class_name
    rid = JSONAPI::ResourceIdentity.new(CommentResource, 13)
    rid2 = JSONAPI::ResourceIdentity.new(PostResource, 13)
    rid3 = JSONAPI::ResourceIdentity.new(SectionResource, 13)
    assert_equal([rid2, rid3, rid].sort, [rid, rid2, rid3])
  end

  def test_sorting_by_id_secondarily
    rid = JSONAPI::ResourceIdentity.new(PostResource, 12)
    rid2 = JSONAPI::ResourceIdentity.new(PostResource, 13)
    rid3 = JSONAPI::ResourceIdentity.new(PostResource, 14)

    assert_equal([rid2, rid3, rid].sort, [rid, rid2, rid3])
  end

  def test_to_s
    rid = JSONAPI::ResourceIdentity.new(PostResource, 12)
    assert_equal(rid.to_s, 'PostResource:12')
  end

  def test_comparisons_return_nil_for_non_resource_identity
    rid = JSONAPI::ResourceIdentity.new(PostResource, 13)
    rid2 = "PostResource:13"
    assert_nil(rid <=> rid2)
  end

  def test_comparisons_allocate_no_new_memory
    rid = JSONAPI::ResourceIdentity.new(PostResource, 13)
    rid2 = JSONAPI::ResourceIdentity.new(PostResource, 13)
    allocation_report = MemoryProfiler.report do
      rid == rid2
    end
    assert_equal 0, allocation_report.total_allocated
  end
end
