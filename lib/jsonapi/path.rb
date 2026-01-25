# frozen_string_literal: true

module JSONAPI
  class Path
    attr_reader :segments, :resource_klass

    def initialize(resource_klass:,
                   path_string:,
                   ensure_default_field: true,
                   parse_fields: true)
      @resource_klass = resource_klass

      current_resource_klass = resource_klass
      @segments = path_string.to_s.split('.').collect do |segment_string|
        segment = PathSegment.parse(source_resource_klass: current_resource_klass,
                                    segment_string: segment_string,
                                    parse_fields: parse_fields)

        current_resource_klass = segment.resource_klass
        segment
      end

      if ensure_default_field && parse_fields && @segments.last.is_a?(PathSegment::Relationship)
        last = @segments.last
        @segments << PathSegment::Field.new(resource_klass: last.resource_klass,
                                            field_name: last.resource_klass._primary_key)
      end
    end

    def relationship_segments
      @segments.select { |p| p.is_a?(PathSegment::Relationship) }
    end

    def relationship_path_string
      relationship_segments.collect(&:to_s).join('.')
    end

    def last_relationship
      if @segments.last.is_a?(PathSegment::Relationship)
        @segments.last
      else
        @segments[-2]
      end
    end
  end
end
