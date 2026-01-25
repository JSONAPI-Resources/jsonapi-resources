# frozen_string_literal: true

module JSONAPI
  class IncludeDirectives
    # Construct an IncludeDirectives Hash from an array of dot separated include strings.
    # For example ['posts.comments.tags']
    # will transform into =>
    # {
    #   posts: {
    #     include_related: {
    #       comments:{
    #         include_related: {
    #           tags: {
    #             include_related: {}
    #           }
    #         }
    #       }
    #     }
    #   }
    # }

    def initialize(resource_klass, includes_array)
      @resource_klass = resource_klass
      @include_directives_hash = { include_related: {} }
      includes_array.each do |include|
        parse_include(include)
      end
    end

    def [](name)
      @include_directives_hash[name]
    end

    private

    def parse_include(include)
      path = JSONAPI::Path.new(resource_klass: @resource_klass,
                               path_string: include,
                               ensure_default_field: false,
                               parse_fields: false)

      current = @include_directives_hash

      path.segments.each do |segment|
        relationship_name = segment.relationship.name.to_sym

        current[:include_related][relationship_name] ||= { include_related: {} }
        current = current[:include_related][relationship_name]
      end
    rescue JSONAPI::Exceptions::InvalidRelationship => _e
      raise JSONAPI::Exceptions::InvalidInclude.new(@resource_klass, include)
    end
  end
end
