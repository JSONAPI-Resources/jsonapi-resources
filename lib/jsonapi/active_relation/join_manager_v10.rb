# frozen_string_literal: true

module JSONAPI
  module ActiveRelation

    # Stores relationship paths starting from the resource_klass, consolidating duplicate paths from
    # relationships, filters and sorts. When joins are made the table aliases are tracked in join_details
    class JoinManagerV10
      attr_reader :resource_klass,
                  :source_relationship,
                  :resource_join_tree,
                  :join_details

      def initialize(resource_klass:,
                     source_relationship: nil,
                     relationships: nil,
                     filters: nil,
                     sort_criteria: nil)

        @resource_klass = resource_klass
        @join_details = nil
        @collected_aliases = Set.new

        @resource_join_tree = {
            root: {
                join_type: :root,
                resource_klasses: {
                    resource_klass => {
                        relationships: {}
                    }
                }
            }
        }
        add_source_relationship(source_relationship)
        add_sort_criteria(sort_criteria)
        add_filters(filters)
        add_relationships(relationships)
      end

      def join(records, options)
        fail "can't be joined again" if @join_details
        @join_details = {}
        perform_joins(records, options)
      end

      # source details will only be on a relationship if the source_relationship is set
      # this method gets the join details whether they are on a relationship or are just pseudo details for the base
      # resource. Specify the resource type for polymorphic relationships
      #
      def source_join_details(type=nil)
        if source_relationship
          related_resource_klass = type ? resource_klass.resource_klass_for(type) : source_relationship.resource_klass
          segment = PathSegment::Relationship.new(relationship: source_relationship, resource_klass: related_resource_klass)
          details = @join_details[segment]
        else
          if type
            details = @join_details["##{type}"]
          else
            details = @join_details['']
          end
        end
        details
      end

      def join_details_by_polymorphic_relationship(relationship, type)
        segment = PathSegment::Relationship.new(relationship: relationship, resource_klass: resource_klass.resource_klass_for(type))
        @join_details[segment]
      end

      def join_details_by_relationship(relationship)
        segment = PathSegment::Relationship.new(relationship: relationship, resource_klass: relationship.resource_klass)
        @join_details[segment]
      end

      def self.get_join_arel_node(records, relationship, join_type, options = {})
        init_join_sources = records.arel.join_sources
        init_join_sources_length = init_join_sources.length

        records = yield(records, options)

        join_sources = records.arel.join_sources
        if join_sources.length > init_join_sources_length
          last_join = (join_sources - init_join_sources).last
        else
          # Try to find a pre-existing join for this table.
          # We can get here if include_optional_linkage_data is true
          # (or always_include_to_xxx_linkage_data),
          # and the user's custom `records` method has already added that join.
          #
          # If we want a left join and there is already an inner/left join,
          # then we can use that.
          # If we want an inner join and there is alrady an inner join,
          # then we can use that (but not a left join, since that doesn't filter things out).
          valid_join_types = [Arel::Nodes::InnerJoin]
          valid_join_types << Arel::Nodes::OuterJoin if join_type == :left
          table_name = relationship.resource_klass._table_name

          last_join = join_sources.find { |j|
            valid_join_types.any? { |t| j.is_a?(t) } && j.left.name == table_name
          }
        end

        if last_join.nil?
          # :nocov:
          warn "get_join_arel_node: No join added"
          # :nocov:
        end

        return records, last_join
      end

      def self.alias_from_arel_node(node)
        case node.left
        when Arel::Table
          node.left.name
        when Arel::Nodes::TableAlias
          node.left.right
        when Arel::Nodes::StringJoin
          # :nocov:
          warn "alias_from_arel_node: Unsupported join type - use custom filtering and sorting"
          nil
          # :nocov:
        end
      end

      private

      def flatten_join_tree_by_depth(join_array = [], node = @resource_join_tree, level = 0)
        join_array[level] = [] unless join_array[level]

        node.each do |relationship, relationship_details|
          relationship_details[:resource_klasses].each do |related_resource_klass, resource_details|
            join_array[level] << { relationship: relationship,
                                   relationship_details: relationship_details,
                                   related_resource_klass: related_resource_klass}
            flatten_join_tree_by_depth(join_array, resource_details[:relationships], level+1)
          end
        end
        join_array
      end

      def add_join_details(join_key, details, check_for_duplicate_alias = true)
        fail "details already set" if @join_details.has_key?(join_key)
        @join_details[join_key] = details

        # Joins are being tracked as they are added to the built up relation. If the same table is added to a
        # relation more than once subsequent versions will be assigned an alias. Depending on the order the joins
        # are made the computed aliases may change. The order this library performs the joins was chosen
        # to prevent this. However if the relation is reordered it should result in reusing on of the earlier
        # aliases (in this case a plain table name). The following check will catch this an raise an exception.
        # An exception is appropriate because not using the correct alias could leak data due to filters and
        # applied permissions being performed on the wrong data.
        if check_for_duplicate_alias && @collected_aliases.include?(details[:alias])
          fail "alias '#{details[:alias]}' has already been added. Possible relation reordering"
        end

        @collected_aliases << details[:alias]
      end

      def perform_joins(records, options)
        join_array = flatten_join_tree_by_depth

        join_array.each do |level_joins|
          level_joins.each do |join_details|
            relationship = join_details[:relationship]
            relationship_details = join_details[:relationship_details]
            related_resource_klass = join_details[:related_resource_klass]
            join_type = relationship_details[:join_type]

            join_options = {
              relationship: relationship,
              relationship_details: relationship_details,
              related_resource_klass: related_resource_klass,
            }

            if relationship == :root
              unless source_relationship
                add_join_details('', {alias: resource_klass._table_name, join_type: :root, join_options: join_options})
              end
              next
            end

            records, join_node = self.class.get_join_arel_node(records, relationship, join_type, options) {|records, options|
              related_resource_klass.join_relationship(
                records: records,
                resource_type: related_resource_klass._type,
                join_type: join_type,
                relationship: relationship,
                options: options)
            }

            details = {alias: self.class.alias_from_arel_node(join_node), join_type: join_type, join_options: join_options}

            if relationship == source_relationship
              if relationship.polymorphic? && relationship.belongs_to?
                add_join_details("##{related_resource_klass._type}", details)
              else
                add_join_details('', details)
              end
            end

            # We're adding the source alias with two keys. We only want the check for duplicate aliases once.
            # See the note in `add_join_details`.
            check_for_duplicate_alias = !(relationship == source_relationship)
            add_join_details(PathSegment::Relationship.new(relationship: relationship, resource_klass: related_resource_klass), details, check_for_duplicate_alias)
          end
        end
        records
      end

      def add_join(path, default_type = :inner, default_polymorphic_join_type = :left)
        if source_relationship
          if source_relationship.polymorphic?
            # Polymorphic paths will come it with the resource_type as the first segment (for example `#documents.comments`)
            # We just need to prepend the relationship portion the
            sourced_path = "#{source_relationship.name}#{path}"
          else
            sourced_path = "#{source_relationship.name}.#{path}"
          end
        else
          sourced_path = path
        end

        join_manager, _field = parse_path_to_tree(sourced_path, resource_klass, default_type, default_polymorphic_join_type)

        @resource_join_tree[:root].deep_merge!(join_manager) { |key, val, other_val|
          if key == :join_type
            if val == other_val
              val
            else
              :inner
            end
          end
        }
      end

      def process_path_to_tree(path_segments, resource_klass, default_join_type, default_polymorphic_join_type)
        node = {
            resource_klasses: {
                resource_klass => {
                    relationships: {}
                }
            }
        }

        segment = path_segments.shift

        if segment.is_a?(PathSegment::Relationship)
          node[:resource_klasses][resource_klass][:relationships][segment.relationship] ||= {}

          # join polymorphic as left joins
          node[:resource_klasses][resource_klass][:relationships][segment.relationship][:join_type] ||=
              segment.relationship.polymorphic? ? default_polymorphic_join_type : default_join_type

          segment.relationship.resource_types.each do |related_resource_type|
            related_resource_klass = resource_klass.resource_klass_for(related_resource_type)

            # If the resource type was specified in the path segment we want to only process the next segments for
            # that resource type, otherwise process for all
            process_all_types = !segment.path_specified_resource_klass?

            if process_all_types || related_resource_klass == segment.resource_klass
              related_resource_tree = process_path_to_tree(path_segments.dup, related_resource_klass, default_join_type, default_polymorphic_join_type)
              node[:resource_klasses][resource_klass][:relationships][segment.relationship].deep_merge!(related_resource_tree)
            end
          end
        end
        node
      end

      def parse_path_to_tree(path_string, resource_klass, default_join_type = :inner, default_polymorphic_join_type = :left)
        path = JSONAPI::Path.new(resource_klass: resource_klass, path_string: path_string)

        field = path.segments[-1]
        return process_path_to_tree(path.segments, resource_klass, default_join_type, default_polymorphic_join_type), field
      end

      def add_source_relationship(source_relationship)
        @source_relationship = source_relationship

        if @source_relationship
          resource_klasses = {}
          source_relationship.resource_types.each do |related_resource_type|
            related_resource_klass = resource_klass.resource_klass_for(related_resource_type)
            resource_klasses[related_resource_klass] = {relationships: {}}
          end

          join_type = source_relationship.polymorphic? ? :left : :inner

          @resource_join_tree[:root][:resource_klasses][resource_klass][:relationships][@source_relationship] = {
              source: true, resource_klasses: resource_klasses, join_type: join_type
          }
        end
      end

      def add_filters(filters)
        return if filters.blank?
        filters.each_key do |filter|
          # Do not add joins for filters with an apply callable. This can be overridden by setting perform_joins to true
          next if resource_klass._allowed_filters[filter].try(:[], :apply) &&
              !resource_klass._allowed_filters[filter].try(:[], :perform_joins)

          add_join(filter, :left)
        end
      end

      def add_sort_criteria(sort_criteria)
        return if sort_criteria.blank?

        sort_criteria.each do |sort|
          add_join(sort[:field], :left)
        end
      end

      def add_relationships(relationships)
        return if relationships.blank?
        relationships.each do |relationship|
          add_join(relationship, :left)
        end
      end
    end
  end
end
