# frozen_string_literal: true

module JSONAPI

  # A tree structure representing the resource structure of the requested resource(s). This is an intermediate structure
  # used to keep track of the resources, by identity, found at different included relationships. It will be flattened and
  # the resource instances will be fetched from the cache or the record store.
  class ResourceTree

    attr_reader :fragments, :related_resource_trees

    # Gets the related Resource Id Tree for a relationship, and creates it first if it does not exist
    #
    # @param relationship [JSONAPI::Relationship]
    #
    # @return [JSONAPI::RelatedResourceTree] the new or existing resource id tree for the requested relationship
    def get_related_resource_tree(relationship)
      relationship_name = relationship.name.to_sym
      @related_resource_trees[relationship_name] ||= RelatedResourceTree.new(relationship, self)
    end

    # Adds each Resource Fragment to the Resources hash
    #
    # @param fragments [Hash]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragments(fragments, include_related)
      fragments.each_value do |fragment|
        add_resource_fragment(fragment, include_related)
      end
    end

    # Adds a Resource Fragment to the fragments hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragment(fragment, include_related)
      init_included_relationships(fragment, include_related)

      @fragments[fragment.identity] = fragment
    end

    # Adds each Resource to the fragments hash
    #
    # @param resource [Hash]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resources(resources, include_related)
      resources.each do |resource|
        add_resource_fragment(JSONAPI::ResourceFragment.new(resource.identity, resource: resource), include_related)
      end
    end

    # Adds a Resource to the fragments hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource(resource, include_related)
      add_resource_fragment(JSONAPI::ResourceFragment.new(resource.identity, resource: resource), include_related)
    end

    private

    def init_included_relationships(fragment, include_related)
      include_related&.each_key do |relationship_name|
        fragment.initialize_related(relationship_name)
      end
    end

    def load_included(resource_klass, source_resource_tree, include_related, options)
       include_related&.each_key do |key|
        relationship = resource_klass._relationship(key)
        relationship_name = relationship.name.to_sym

        find_related_resource_options = options.except(:filters, :sort_criteria, :paginator)
        find_related_resource_options[:sort_criteria] = relationship.resource_klass.default_sort
        find_related_resource_options[:cache] = resource_klass.caching?

        related_fragments = resource_klass.find_included_fragments(source_resource_tree.fragments.values,
                                                                   relationship,
                                                                   find_related_resource_options)

        related_resource_tree = source_resource_tree.get_related_resource_tree(relationship)
        related_resource_tree.add_resource_fragments(related_fragments, include_related[key][:include_related])

        # Now recursively get the related resources for the currently found resources
        load_included(relationship.resource_klass,
                      related_resource_tree,
                      include_related[relationship_name][:include_related],
                      options)
      end
    end
  end

  class PrimaryResourceTree < ResourceTree

    # Creates a PrimaryResourceTree with no resources and no related ResourceTrees
    def initialize(fragments: nil, resources: nil, resource: nil, include_related: nil, options: nil)
      @fragments ||= {}
      @related_resource_trees ||= {}
      if fragments || resources || resource
        if fragments
          add_resource_fragments(fragments, include_related)
        end

        if resources
          add_resources(resources, include_related)
        end

        if resource
          add_resource(resource, include_related)
        end

        complete_includes!(include_related, options)
      end
    end

    # Adds a Resource Fragment to the fragments hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragment(fragment, include_related)
      fragment.primary = true
      super(fragment, include_related)
    end

    def complete_includes!(include_related, options)
      # ToDo: can we skip if more than one resource_klass found?
      resource_klasses = Set.new
      @fragments.each_key { |identity| resource_klasses << identity.resource_klass }

      resource_klasses.each { |resource_klass| load_included(resource_klass, self, include_related, options) }

      self
    end
  end

  class RelatedResourceTree < ResourceTree

    attr_reader :parent_relationship, :source_resource_tree

    # Creates a RelatedResourceTree with no resources and no related ResourceTrees. A connection to the parent
    # ResourceTree is maintained.
    #
    # @param parent_relationship [JSONAPI::Relationship]
    # @param source_resource_tree [JSONAPI::ResourceTree]
    #
    # @return [JSONAPI::RelatedResourceTree] the new or existing resource id tree for the requested relationship
    def initialize(parent_relationship, source_resource_tree)
      @fragments ||= {}
      @related_resource_trees ||= {}

      @parent_relationship = parent_relationship
      @source_resource_tree = source_resource_tree
    end

    # Adds a Resource Fragment to the fragments hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragment(fragment, include_related)
      init_included_relationships(fragment, include_related)

      fragment.related_from.each do |rid|
        @source_resource_tree.fragments[rid].add_related_identity(parent_relationship.name, fragment.identity)
      end

      if @fragments[fragment.identity]
        @fragments[fragment.identity].related_from.merge(fragment.related_from)
        fragment.related.each_pair do |relationship_name, rids|
          if rids
            @fragments[fragment.identity].merge_related_identities(relationship_name, rids)
          end
        end
      else
        @fragments[fragment.identity] = fragment
      end
    end
  end
end
