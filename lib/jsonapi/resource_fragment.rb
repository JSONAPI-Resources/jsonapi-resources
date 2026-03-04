# frozen_string_literal: true

module JSONAPI

  # A ResourceFragment holds a ResourceIdentity and associated partial resource data.
  #
  # The following partial resource data may be stored
  # cache - the value of the cache field for the resource instance
  # related - a hash of arrays of related resource identities, grouped by relationship name
  # related_from - a set of related resource identities that loaded the fragment
  # resource - a resource instance
  #

  class ResourceFragment
    attr_reader :identity, :related_from, :related, :resource

    attr_accessor :primary, :cache

    alias :cache_field :cache #ToDo: Rename one or the other

    def initialize(identity, resource: nil, cache: nil, primary: false)
      @identity = identity
      @cache = cache
      @resource = resource
      @primary = primary

      @related = {}
      @related_from = JSONAPI.configuration.related_identities_set.new
    end

    def initialize_related(relationship_name)
      @related[relationship_name.to_sym] ||= Set.new
    end

    def add_related_identity(relationship_name, identity)
      initialize_related(relationship_name)
      @related[relationship_name.to_sym] << identity if identity
    end

    def merge_related_identities(relationship_name, identities)
      initialize_related(relationship_name)
      @related[relationship_name.to_sym].merge(identities) if identities
    end

    def add_related_from(identity)
      @related_from << identity
    end
  end
end
