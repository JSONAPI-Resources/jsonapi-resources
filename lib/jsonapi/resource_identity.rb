# frozen_string_literal: true

module JSONAPI

  # ResourceIdentity describes a unique identity of a resource in the system.
  # This consists of a Resource class and an identifier that is unique within
  # that Resource class. ResourceIdentities are intended to be used as hash
  # keys to provide ordered mixing of resource types in result sets.
  #
  #
  # == Creating a ResourceIdentity
  #
  # rid = ResourceIdentity.new(PostResource, 12)
  #
  class ResourceIdentity
    include Comparable

    # Store the identity parts as an array to avoid allocating a new array for the hash method to work on
    def initialize(resource_klass, id)
      @identity_parts = [resource_klass, id]
    end

    def resource_klass
      @identity_parts[0]
    end

    def id
      @identity_parts[1]
    end

    def ==(other)
      # :nocov:
      eql?(other)
      # :nocov:
    end

    def eql?(other)
      hash == other.hash
    end

    def hash
      @identity_parts.hash
    end

    def <=>(other_identity)
      return nil unless other_identity.is_a?(ResourceIdentity)

      case self.resource_klass.name <=> other_identity.resource_klass.name
      when -1
        -1
      when 1
        1
      else
        self.id <=> other_identity.id
      end
    end

    # Creates a string representation of the identifier.
    def to_s
      # :nocov:
      "#{resource_klass.name}:#{id}"
      # :nocov:
    end
  end
end
