# frozen_string_literal: true

module JSONAPI
  module ActiveRelationRetrieval
    module FindRelatedThroughPrimary
      module ClassMethods
        def find_related_monomorphic_fragments_through_primary(source_fragments, relationship, options, connect_source_identity)
          filters = options.fetch(:filters, {})
          source_ids = source_fragments.collect {|item| item.identity.id}

          include_directives = options.fetch(:include_directives, {})
          resource_klass = relationship.resource_klass
          linkage_relationships = resource_klass.to_one_relationships_for_linkage(include_directives[:include_related])

          sort_criteria = []
          options[:sort_criteria].try(:each) do |sort|
            field = sort[:field].to_s == 'id' ? resource_klass._primary_key : sort[:field]
            sort_criteria << { field: field, direction: sort[:direction] }
          end

          join_manager = ActiveRelation::JoinManagerThroughPrimary.new(resource_klass: self,
                                                                       source_relationship: relationship,
                                                                       relationships: linkage_relationships.collect(&:name),
                                                                       sort_criteria: sort_criteria,
                                                                       filters: filters)

          paginator = options[:paginator]

          records = apply_request_settings_to_records(records: records_for_source_to_related(options),
                                                      resource_klass: resource_klass,
                                                      sort_criteria: sort_criteria,
                                                      primary_keys: source_ids,
                                                      paginator: paginator,
                                                      filters: filters,
                                                      join_manager: join_manager,
                                                      options: options)

          resource_table_alias = join_manager.join_details_by_relationship(relationship)[:alias]

          pluck_fields = [
            Arel.sql("#{_table_name}.#{_primary_key} AS \"source_id\""),
            sql_field_with_alias(resource_table_alias, resource_klass._primary_key)
          ]

          cache_field = resource_klass.attribute_to_model_field(:_cache_field) if options[:cache]
          if cache_field
            pluck_fields << sql_field_with_alias(resource_table_alias, cache_field[:name])
          end

          linkage_fields = []

          linkage_relationships.each do |linkage_relationship|
            linkage_relationship_name = linkage_relationship.name

            if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
              linkage_relationship.resource_types.each do |resource_type|
                klass = resource_klass_for(resource_type)
                linkage_fields << {relationship_name: linkage_relationship_name, resource_klass: klass}

                linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
                primary_key = klass._primary_key
                pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
              end
            else
              klass = linkage_relationship.resource_klass
              linkage_fields << {relationship_name: linkage_relationship_name, resource_klass: klass}

              linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
              primary_key = klass._primary_key
              pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
            end
          end

          sort_fields = options.dig(:_relation_helper_options, :sort_fields)
          sort_fields.try(:each) do |field|
            pluck_fields << Arel.sql(field)
          end

          fragments = {}
          rows = records.distinct.pluck(*pluck_fields)
          rows.each do |row|
            rid = JSONAPI::ResourceIdentity.new(resource_klass, row[1])

            fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

            attributes_offset = 2

            if cache_field
              fragments[rid].cache = cast_to_attribute_type(row[attributes_offset], cache_field[:type])
              attributes_offset+= 1
            end

            source_rid = JSONAPI::ResourceIdentity.new(self, row[0])

            fragments[rid].add_related_from(source_rid)

            linkage_fields.each do |linkage_field|
              fragments[rid].initialize_related(linkage_field[:relationship_name])
              related_id = row[attributes_offset]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field[:resource_klass], related_id)
                fragments[rid].add_related_identity(linkage_field[:relationship_name], related_rid)
              end
              attributes_offset+= 1
            end

            if connect_source_identity
              inverse_relationship = relationship._inverse_relationship
              fragments[rid].add_related_identity(inverse_relationship.name, source_rid) if inverse_relationship.present?
            end
          end

          fragments
        end

        # Gets resource identities where the related resource is polymorphic and the resource type and id
        # are stored on the primary resources. Cache fields will always be on the related resources.
        def find_related_polymorphic_fragments_through_primary(source_fragments, relationship, options, connect_source_identity)
          filters = options.fetch(:filters, {})
          source_ids = source_fragments.collect {|item| item.identity.id}

          resource_klass = relationship.resource_klass
          include_directives = options.fetch(:include_directives, {})

          linkage_relationship_paths = []

          resource_types = relationship.resource_types

          resource_types.each do |resource_type|
            related_resource_klass = resource_klass_for(resource_type)
            relationships = related_resource_klass.to_one_relationships_for_linkage(include_directives[:include_related])
            relationships.each do |r|
              linkage_relationship_paths << "##{resource_type}.#{r.name}"
            end
          end

          join_manager = ActiveRelation::JoinManagerThroughPrimary.new(resource_klass: self,
                                                                       source_relationship: relationship,
                                                                       relationships: linkage_relationship_paths,
                                                                       filters: filters)

          paginator = options[:paginator]

          # Note: We will sort by the source table. Without using unions we can't sort on a polymorphic relationship
          # in any manner that makes sense
          records = apply_request_settings_to_records(records: records_for_source_to_related(options),
                                                      resource_klass: resource_klass,
                                                      sort_primary: true,
                                                      primary_keys: source_ids,
                                                      paginator: paginator,
                                                      filters: filters,
                                                      join_manager: join_manager,
                                                      options: options)

          primary_key = concat_table_field(_table_name, _primary_key)
          related_key = concat_table_field(_table_name, relationship.foreign_key)
          related_type = concat_table_field(_table_name, relationship.polymorphic_type)

          pluck_fields = [
            Arel.sql("#{primary_key} AS #{alias_table_field(_table_name, _primary_key)}"),
            Arel.sql("#{related_key} AS #{alias_table_field(_table_name, relationship.foreign_key)}"),
            Arel.sql("#{related_type} AS #{alias_table_field(_table_name, relationship.polymorphic_type)}")
          ]

          # Get the additional fields from each relation. There's a limitation that the fields must exist in each relation

          relation_positions = {}
          relation_index = pluck_fields.length

          # Add resource specific fields
          if resource_types.nil? || resource_types.length == 0
            # :nocov:
            warn "No resource types found for polymorphic relationship."
            # :nocov:
          else
            resource_types.try(:each) do |type|
              related_klass = resource_klass_for(type.to_s)

              cache_field = related_klass.attribute_to_model_field(:_cache_field) if options[:cache]

              table_alias = join_manager.source_join_details(type)[:alias]

              cache_offset = relation_index
              if cache_field
                pluck_fields << sql_field_with_alias(table_alias, cache_field[:name])
                relation_index+= 1
              end

              relation_positions[type] = {relation_klass: related_klass,
                                          cache_field: cache_field,
                                          cache_offset: cache_offset}
            end
          end

          # Add to_one linkage fields
          linkage_fields = []
          linkage_offset = relation_index

          linkage_relationship_paths.each do |linkage_relationship_path|
            path = JSONAPI::Path.new(resource_klass: self,
                                     path_string: "#{relationship.name}#{linkage_relationship_path}",
                                     ensure_default_field: false)

            linkage_relationship = path.segments[-1].relationship

            if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
              linkage_relationship.resource_types.each do |resource_type|
                klass = resource_klass_for(resource_type)
                linkage_fields << {relationship: linkage_relationship, resource_klass: klass}

                linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
                primary_key = klass._primary_key
                pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
              end
            else
              klass = linkage_relationship.resource_klass
              linkage_fields << {relationship: linkage_relationship, resource_klass: klass}

              linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
              primary_key = klass._primary_key
              pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
            end
          end

          rows = records.distinct.pluck(*pluck_fields)

          related_fragments = {}

          rows.each do |row|
            unless row[1].nil? || row[2].nil?
              related_klass = resource_klass_for(row[2])

              rid = JSONAPI::ResourceIdentity.new(related_klass, row[1])
              related_fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

              source_rid = JSONAPI::ResourceIdentity.new(self, row[0])
              related_fragments[rid].add_related_from(source_rid)

              if connect_source_identity
                inverse_relationship = relationship._inverse_relationship
                related_fragments[rid].add_related_identity(inverse_relationship.name, source_rid) if inverse_relationship.present?
              end

              relation_position = relation_positions[row[2].underscore.pluralize]
              model_fields = relation_position[:model_fields]
              cache_field = relation_position[:cache_field]
              cache_offset = relation_position[:cache_offset]
              field_offset = relation_position[:field_offset]

              if cache_field
                related_fragments[rid].cache = cast_to_attribute_type(row[cache_offset], cache_field[:type])
              end

              linkage_fields.each_with_index do |linkage_field_details, idx|
                relationship = linkage_field_details[:relationship]
                related_fragments[rid].initialize_related(relationship.name)
                related_id = row[linkage_offset + idx]
                if related_id
                  related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                  related_fragments[rid].add_related_identity(relationship.name, related_rid)
                end
              end
            end
          end

          related_fragments
        end
      end
    end
  end
end
