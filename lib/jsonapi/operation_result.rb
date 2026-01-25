# frozen_string_literal: true

module JSONAPI
  class OperationResult
    attr_accessor :code
    attr_accessor :meta
    attr_accessor :links
    attr_accessor :options
    attr_accessor :warnings

    def initialize(code, options = {})
      @code = Rack::Utils.status_code(code)
      @options = options
      @meta = options.fetch(:meta, {})
      @links = options.fetch(:links, {})
      @warnings = options.fetch(:warnings, {})
    end

    def to_hash(serializer = nil)
      {}
    end
  end

  class ErrorsOperationResult < OperationResult
    attr_accessor :errors

    def initialize(code, errors, options = {})
      @errors = errors
      super(code, options)
    end

    def to_hash(serializer = nil)
      {
        errors: errors.collect do |error|
          # :nocov:
          error.to_hash
          # :nocov:
        end
      }
    end
  end

  class ResourceSetOperationResult < OperationResult
    attr_accessor :resource_set, :pagination_params

    def initialize(code, resource_set, options = {})
      @resource_set = resource_set
      @pagination_params = options.fetch(:pagination_params, {})
      super(code, options)
    end

    def to_hash(serializer)
      if serializer
        serializer.serialize_resource_set_to_hash_single(resource_set)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class ResourcesSetOperationResult < OperationResult
    attr_accessor :resource_set, :pagination_params, :record_count, :page_count

    def initialize(code, resource_set, options = {})
      @resource_set = resource_set
      @pagination_params = options.fetch(:pagination_params, {})
      @record_count = options[:record_count]
      @page_count = options[:page_count]
      super(code, options)
    end

    def to_hash(serializer)
      if serializer
        serializer.serialize_resource_set_to_hash_plural(resource_set)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class RelatedResourcesSetOperationResult < ResourcesSetOperationResult
    attr_accessor :resource_set, :source_resource, :_type

    def initialize(code, source_resource, type, resource_set, options = {})
      @source_resource = source_resource
      @_type = type
      super(code, resource_set, options)
    end

    def to_hash(serializer = nil)
      if serializer
        serializer.serialize_related_resource_set_to_hash_plural(resource_set, source_resource)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end

  class RelationshipOperationResult < OperationResult
    attr_accessor :parent_resource, :relationship, :resource_ids

    def initialize(code, parent_resource, relationship, resource_ids, options = {})
      @parent_resource = parent_resource
      @relationship = relationship
      @resource_ids = resource_ids
      super(code, options)
    end

    def to_hash(serializer = nil)
      if serializer
        serializer.serialize_to_relationship_hash(parent_resource, relationship, resource_ids)
      else
        # :nocov:
        {}
        # :nocov:
      end
    end
  end
end
