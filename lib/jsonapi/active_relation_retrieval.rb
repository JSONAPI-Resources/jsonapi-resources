# frozen_string_literal: true

module JSONAPI
  module ActiveRelationRetrieval
    include ::JSONAPI::RelationRetrieval

    def find_related_ids(relationship, options = {})
      self.class.find_related_fragments(self, relationship, options).keys.collect { |rid| rid.id }
    end

    module ClassMethods
      # Finds Resources using the `filters`. Pagination and sort options are used when provided
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Hash] :sort_criteria The `sort criteria`
      # @option options [Hash] :include_directives The `include_directives`
      #
      # @return [Array<Resource>] the Resource instances matching the filters, sorting and pagination rules.
      def find(filters, options = {})
        sort_criteria = options.fetch(:sort_criteria) { [] }

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       filters: filters,
                                                       sort_criteria: sort_criteria)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records(options),
                               sort_criteria: sort_criteria,filters: filters,
                               join_manager: join_manager,
                               paginator: paginator,
                               options: options)

        resources_for(records, options[:context])
      end

      # Counts Resources found using the `filters`
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count(filters, options = {})
        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       filters: filters)

        records = apply_request_settings_to_records(records: records(options),
                               filters: filters,
                               join_manager: join_manager,
                               options: options)

        count_records(records)
      end

      # Returns the single Resource identified by `key`
      #
      # @param key the primary key of the resource to find
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_key(key, options = {})
        record = find_record_by_key(key, options)
        resource_for(record, options[:context])
      end

      # Returns an array of Resources identified by the `keys` array
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_keys(keys, options = {})
        records = find_records_by_keys(keys, options)
        resources_for(records, options[:context])
      end

      # Returns an array of Resources identified by the `keys` array. The resources are not filtered as this
      # will have been done in a prior step
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_to_populate_by_keys(keys, options = {})
        records = records_for_populate(options).where(_primary_key => keys)
        resources_for(records, options[:context])
      end

      # Finds Resource fragments using the `filters`. Pagination and sort options are used when provided.
      # Note: This is incompatible with Polymorphic resources (which are going to come from two separate tables)
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Hash] :sort_criteria The `sort criteria`
      # @option options [Hash] :include_directives The `include_directives`
      # @option options [Boolean] :cache Return the resources' cache field
      #
      # @return [Hash{ResourceIdentity => {identity: => ResourceIdentity, cache: cache_field}]
      #    the ResourceInstances matching the filters, sorting, and pagination rules along with any request
      #    additional_field values
      def find_fragments(filters, options = {})
        include_directives = options.fetch(:include_directives, {})
        resource_klass = self

        fragments = {}

        linkage_relationships = to_one_relationships_for_linkage(include_directives[:include_related])

        sort_criteria = options.fetch(:sort_criteria) { [] }

        join_manager = ActiveRelation::JoinManager.new(resource_klass: resource_klass,
                                                       source_relationship: nil,
                                                       relationships: linkage_relationships.collect(&:name),
                                                       sort_criteria: sort_criteria,
                                                       filters: filters)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records(options),
                               filters: filters,
                               sort_criteria: sort_criteria,
                               paginator: paginator,
                               join_manager: join_manager,
                               options: options)

        if options[:cache]
          # This alias is going to be resolve down to the model's table name and will not actually be an alias
          resource_table_alias = resource_klass._table_name

          pluck_fields = [sql_field_with_alias(resource_table_alias, resource_klass._primary_key)]

          cache_field = attribute_to_model_field(:_cache_field)
          pluck_fields << sql_field_with_alias(resource_table_alias, cache_field[:name])

          linkage_fields = []

          linkage_relationships.each do |linkage_relationship|
            linkage_relationship_name = linkage_relationship.name

            if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
              linkage_relationship.resource_types.each do |resource_type|
                klass = resource_klass_for(resource_type)
                linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
                primary_key = klass._primary_key

                linkage_fields << {relationship_name: linkage_relationship_name,
                                   resource_klass: klass,
                                   field: sql_field_with_alias(linkage_table_alias, primary_key),
                                   alias: alias_table_field(linkage_table_alias, primary_key)}

                pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
              end
            else
              klass = linkage_relationship.resource_klass
              linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
              fail "Missing linkage_table_alias for #{linkage_relationship}" unless linkage_table_alias
              primary_key = klass._primary_key

              linkage_fields << {relationship_name: linkage_relationship_name,
                                 resource_klass: klass,
                                 field: sql_field_with_alias(linkage_table_alias, primary_key),
                                 alias: alias_table_field(linkage_table_alias, primary_key)}

              pluck_fields << sql_field_with_alias(linkage_table_alias, primary_key)
            end
          end

          sort_fields = options.dig(:_relation_helper_options, :sort_fields)
          sort_fields.try(:each) do |field|
            pluck_fields << Arel.sql(field)
          end

          rows = records.pluck(*pluck_fields)
          rows.each do |row|
            rid = JSONAPI::ResourceIdentity.new(resource_klass, pluck_fields.length == 1 ? row : row[0])

            fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)
            attributes_offset = 2

            fragments[rid].cache = cast_to_attribute_type(row[1], cache_field[:type])

            linkage_fields.each do |linkage_field_details|
              fragments[rid].initialize_related(linkage_field_details[:relationship_name])
              related_id = row[attributes_offset]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                fragments[rid].add_related_identity(linkage_field_details[:relationship_name], related_rid)
              end
              attributes_offset+= 1
            end
          end

          if JSONAPI.configuration.warn_on_performance_issues && (rows.length > fragments.length)
            warn "Performance issue detected: `#{self.name.to_s}.records` returned non-normalized results in `#{self.name.to_s}.find_fragments`."
          end
        else
          linkage_fields = []

          linkage_relationships.each do |linkage_relationship|
            linkage_relationship_name = linkage_relationship.name

            if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
              linkage_relationship.resource_types.each do |resource_type|
                klass = resource_klass_for(resource_type)
                linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]
                primary_key = klass._primary_key

                select_alias = "jr_l_#{linkage_relationship_name}_#{resource_type}_pk"
                select_alias_statement = sql_field_with_fixed_alias(linkage_table_alias, primary_key, select_alias)

                linkage_fields << {relationship_name: linkage_relationship_name,
                                   resource_klass: klass,
                                   select: select_alias_statement,
                                   select_alias: select_alias}
              end
            else
              klass = linkage_relationship.resource_klass
              linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
              fail "Missing linkage_table_alias for #{linkage_relationship}" unless linkage_table_alias
              primary_key = klass._primary_key

              select_alias = "jr_l_#{linkage_relationship_name}_pk"
              select_alias_statement = sql_field_with_fixed_alias(linkage_table_alias, primary_key, select_alias)
              linkage_fields << {relationship_name: linkage_relationship_name,
                                 resource_klass: klass,
                                 select: select_alias_statement,
                                 select_alias: select_alias}
            end
          end


          if linkage_fields.any?
            records = records.select(linkage_fields.collect {|f| f[:select]})
          end

          records = records.select(concat_table_field(_table_name, Arel.star))
          resources = resources_for(records, options[:context])

          resources.each do |resource|
            rid = resource.identity
            fragments[rid] ||= JSONAPI::ResourceFragment.new(rid, resource: resource)

            linkage_fields.each do |linkage_field_details|
              fragments[rid].initialize_related(linkage_field_details[:relationship_name])
              related_id = resource._model.attributes[linkage_field_details[:select_alias]]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                fragments[rid].add_related_identity(linkage_field_details[:relationship_name], related_rid)
              end
            end
          end
        end

        fragments
      end

      # Finds Resource Fragments related to the source resources through the specified relationship
      #
      # @param source_rids [Array<ResourceIdentity>] The resources to find related ResourcesIdentities for
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Boolean] :cache Return the resources' cache field
      #
      # @return [Hash{ResourceIdentity => {identity: => ResourceIdentity, cache: cache_field, related: {relationship_name: [] }}}]
      #    the ResourceInstances matching the filters, sorting, and pagination rules along with any request
      #    additional_field values
      def find_related_fragments(source_fragment, relationship, options = {})
        if relationship.polymorphic? # && relationship.foreign_key_on == :self
          source_resource_klasses = if relationship.foreign_key_on == :self
                                      relationship.polymorphic_types.collect do |polymorphic_type|
                                        resource_klass_for(polymorphic_type)
                                      end
                                    else
                                      source.collect { |fragment| fragment.identity.resource_klass }.to_set
                                    end

          fragments = {}
          source_resource_klasses.each do |resource_klass|
            inverse_direct_relationship = _relationship(resource_klass._type.to_s.singularize)

            fragments.merge!(resource_klass.find_related_fragments_from_inverse([source_fragment], inverse_direct_relationship, options, false))
          end
          fragments
        else
          relationship.resource_klass.find_related_fragments_from_inverse([source_fragment], relationship, options, false)
        end
      end

      def find_included_fragments(source_fragments, relationship, options)
        if relationship.polymorphic? # && relationship.foreign_key_on == :self
          source_resource_klasses = if relationship.foreign_key_on == :self
                                      relationship.polymorphic_types.collect do |polymorphic_type|
                                        resource_klass_for(polymorphic_type)
                                      end
                                    else
                                      source_fragments.collect { |fragment| fragment.identity.resource_klass }.to_set
                                    end

          fragments = {}
          source_resource_klasses.each do |resource_klass|
            inverse_direct_relationship = _relationship(resource_klass._type.to_s.singularize)

            fragments.merge!(resource_klass.find_related_fragments_from_inverse(source_fragments, inverse_direct_relationship, options, true))
          end
          fragments
        else
          relationship.resource_klass.find_related_fragments_from_inverse(source_fragments, relationship, options, true)
        end
      end

      def find_related_fragments_from_inverse(source, source_relationship, options, connect_source_identity)
        inverse_relationship = source_relationship._inverse_relationship
        return {} if inverse_relationship.blank?

        parent_resource_klass = inverse_relationship.resource_klass

        include_directives = options.fetch(:include_directives, {})

        # ToDo: Handle resources vs identities
        source_ids = source.collect {|item| item.identity.id}

        filters = options.fetch(:filters, {})

        linkage_relationships = to_one_relationships_for_linkage(include_directives[:include_related])

        sort_criteria = []

        # Do not sort the related_fragments. This can be keyed off `connect_source_identity` to indicate whether this
        # is a related resource primary step vs. an include step.
        sort_related_fragments = !connect_source_identity

        if sort_related_fragments
          options[:sort_criteria].try(:each) do |sort|
            field = sort[:field].to_s == 'id' ? _primary_key : sort[:field]
            sort_criteria << { field: field, direction: sort[:direction] }
          end
        end

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       source_relationship: inverse_relationship,
                                                       relationships: linkage_relationships.collect(&:name),
                                                       sort_criteria: sort_criteria,
                                                       filters: filters)

        paginator = options[:paginator]

        records = apply_request_settings_to_records(records: records(options),
                                                    sort_criteria: sort_criteria,
                                                    source_ids: source_ids,
                                                    paginator: paginator,
                                                    filters: filters,
                                                    join_manager: join_manager,
                                                    options: options)

        fragments = {}

        if options[:cache]
          # This alias is going to be resolve down to the model's table name and will not actually be an alias
          resource_table_alias = self._table_name
          parent_table_alias = join_manager.join_details_by_relationship(inverse_relationship)[:alias]

          pluck_fields = [
            sql_field_with_alias(resource_table_alias, self._primary_key),
            sql_field_with_alias(parent_table_alias, parent_resource_klass._primary_key)
          ]

          cache_field = attribute_to_model_field(:_cache_field)
          pluck_fields << sql_field_with_alias(resource_table_alias, cache_field[:name])

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

          rows = records.distinct.pluck(*pluck_fields)
          rows.each do |row|
            rid = JSONAPI::ResourceIdentity.new(self, row[0])
            fragments[rid] ||= JSONAPI::ResourceFragment.new(rid)

            parent_rid = JSONAPI::ResourceIdentity.new(parent_resource_klass, row[1])
            fragments[rid].add_related_from(parent_rid)

            if connect_source_identity
              fragments[rid].add_related_identity(inverse_relationship.name, parent_rid)
            end

            attributes_offset = 2
            fragments[rid].cache = cast_to_attribute_type(row[attributes_offset], cache_field[:type])

            attributes_offset += 1

            linkage_fields.each do |linkage_field|
              fragments[rid].initialize_related(linkage_field[:relationship_name])
              related_id = row[attributes_offset]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field[:resource_klass], related_id)
                fragments[rid].add_related_identity(linkage_field[:relationship_name], related_rid)
              end
              attributes_offset += 1
            end
          end
        else
          linkage_fields = []

          linkage_relationships.each do |linkage_relationship|
            linkage_relationship_name = linkage_relationship.name

            if linkage_relationship.polymorphic? && linkage_relationship.belongs_to?
              linkage_relationship.resource_types.each do |resource_type|
                klass = linkage_relationship.resource_klass.resource_klass_for(resource_type)
                primary_key = klass._primary_key
                linkage_table_alias = join_manager.join_details_by_polymorphic_relationship(linkage_relationship, resource_type)[:alias]

                select_alias = "jr_l_#{linkage_relationship_name}_#{resource_type}_pk"
                select_alias_statement = sql_field_with_fixed_alias(linkage_table_alias, primary_key, select_alias)
                linkage_fields << {relationship_name: linkage_relationship_name,
                                   resource_klass: klass,
                                   select: select_alias_statement,
                                   select_alias: select_alias}
              end
            else
              klass = linkage_relationship.resource_klass
              primary_key = klass._primary_key
              linkage_table_alias = join_manager.join_details_by_relationship(linkage_relationship)[:alias]
              select_alias = "jr_l_#{linkage_relationship_name}_pk"
              select_alias_statement = sql_field_with_fixed_alias(linkage_table_alias, primary_key, select_alias)


              linkage_fields << {relationship_name: linkage_relationship_name,
                                 resource_klass: klass,
                                 select: select_alias_statement,
                                 select_alias: select_alias}
            end
          end

          parent_table_alias = join_manager.join_details_by_relationship(inverse_relationship)[:alias]
          source_field = sql_field_with_fixed_alias(parent_table_alias, parent_resource_klass._primary_key, "jr_source_id")

          records = records.select(concat_table_field(_table_name, Arel.star), source_field)

          if linkage_fields.any?
            records = records.select(linkage_fields.collect {|f| f[:select]})
          end

          resources = resources_for(records, options[:context])

          resources.each do |resource|
            rid = resource.identity

            fragments[rid] ||= JSONAPI::ResourceFragment.new(rid, resource: resource)

            parent_rid = JSONAPI::ResourceIdentity.new(parent_resource_klass, resource._model.attributes['jr_source_id'])

            if connect_source_identity
              fragments[rid].add_related_identity(inverse_relationship.name, parent_rid)
            end

            fragments[rid].add_related_from(parent_rid)

            linkage_fields.each do |linkage_field_details|
              fragments[rid].initialize_related(linkage_field_details[:relationship_name])
              related_id = resource._model.attributes[linkage_field_details[:select_alias]]
              if related_id
                related_rid = JSONAPI::ResourceIdentity.new(linkage_field_details[:resource_klass], related_id)
                fragments[rid].add_related_identity(linkage_field_details[:relationship_name], related_rid)
              end
            end
          end
        end

        fragments
      end

      # Counts Resources related to the source resource through the specified relationship
      #
      # @param source_rid [ResourceIdentity] Source resource identifier
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count

      def count_related(source, relationship, options = {})
        relationship.resource_klass.count_related_from_inverse(source, relationship, options)
      end

      def count_related_from_inverse(source_resource, source_relationship, options = {})
        inverse_relationship = source_relationship._inverse_relationship
        return -1 if inverse_relationship.blank?

        related_klass = inverse_relationship.resource_klass

        filters = options.fetch(:filters, {})

        # Joins in this case are related to the related_klass
        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       source_relationship: inverse_relationship,
                                                       filters: filters)

        records = apply_request_settings_to_records(records: records(options),
                                                    resource_klass: self,
                                                    source_ids: source_resource.id,
                                                    join_manager: join_manager,
                                                    filters: filters,
                                                    options: options)

        related_alias = join_manager.join_details_by_relationship(inverse_relationship)[:alias]

        records = records.select(Arel.sql("#{concat_table_field(related_alias, related_klass._primary_key)}"))

        count_records(records)
      end

      # This resource class (ActiveRelationResource) uses an `ActiveRecord::Relation` as the starting point for
      # retrieving models. From this relation filters, sorts and joins are applied as needed.
      # Depending on which phase of the request processing different `records` methods will be called, giving the user
      # the opportunity to override them differently for performance and security reasons.

      # begin `records`methods

      # Base for the `records` methods that follow and is not directly used for accessing model data by this class.
      # Overriding this method gives a single place to affect the `ActiveRecord::Relation` used for the resource.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_base(_options = {})
        _model_class.all
      end

      # The `ActiveRecord::Relation` used for finding user requested models. This may be overridden to enforce
      # permissions checks on the request.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records(options = {})
        records_base(options)
      end

      # The `ActiveRecord::Relation` used for populating the ResourceSet. Only resources that have been previously
      # identified through the `records` method will be accessed. Thus it should not be necessary to reapply permissions
      # checks. However if the model needs to include other models adding `includes` is appropriate
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_for_populate(options = {})
        records_base(options)
      end

      # The `ActiveRecord::Relation` used for the finding related resources.
      #
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [ActiveRecord::Relation]
      def records_for_source_to_related(options = {})
        records_base(options)
      end

      # end `records` methods

      def apply_join(records:, relationship:, resource_type:, join_type:, options:)
        if relationship.polymorphic? && relationship.belongs_to?
          case join_type
          when :inner
            records = records.joins(resource_type.to_s.singularize.to_sym)
          when :left
            records = records.joins_left(resource_type.to_s.singularize.to_sym)
          end
        else
          relation_name = relationship.relation_name(options)

          # if relationship.alias_on_join
          #   alias_name = "#{relationship.preferred_alias}_#{relation_name}"
          #   case join_type
          #   when :inner
          #     records = records.joins_with_alias(relation_name, alias_name)
          #   when :left
          #     records = records.left_joins_with_alias(relation_name, alias_name)
          #   end
          # else
            case join_type
            when :inner
              records = records.joins(relation_name)
            when :left
              records = records.left_joins(relation_name)
            end
          end
        # end
        records
      end

      def relationship_records(relationship:, join_type: :inner, resource_type: nil, options: {})
        records = relationship.parent_resource.records_for_source_to_related(options)
        strategy = relationship.options[:apply_join]

        if strategy
          records = call_method_or_proc(strategy, records, relationship, resource_type, join_type, options)
        else
          records = apply_join(records: records,
                               relationship: relationship,
                               resource_type: resource_type,
                               join_type: join_type,
                               options: options)
        end

        records
      end

      def join_relationship(records:, relationship:, resource_type: nil, join_type: :inner, options: {})
        relationship_records = relationship_records(relationship: relationship,
                                                    join_type: join_type,
                                                    resource_type: resource_type,
                                                    options: options)
        records.merge(relationship_records)
      end


      # protected

      def find_record_by_key(key, options = {})
        record = apply_request_settings_to_records(records: records(options), primary_keys: key, options: options).first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if record.nil?
        record
      end

      def find_records_by_keys(keys, options = {})
        apply_request_settings_to_records(records: records(options), primary_keys: keys, options: options)
      end

      def apply_request_settings_to_records(records:,
                                            join_manager: ActiveRelation::JoinManager.new(resource_klass: self),
                                            resource_klass: self,
                                            source_ids: nil,
                                            filters: {},
                                            primary_keys: nil,
                                            sort_criteria: nil,
                                            sort_primary: nil,
                                            paginator: nil,
                                            options: {})

        options[:_relation_helper_options] = { join_manager: join_manager, sort_fields: [] }

        records = resource_klass.apply_joins(records, join_manager, options)

        if source_ids
          source_join_details = join_manager.source_join_details
          source_primary_key = join_manager.source_relationship.resource_klass._primary_key

          source_aliased_key = concat_table_field(source_join_details[:alias], source_primary_key, false)
          records = records.where(source_aliased_key => source_ids)
        end

        if primary_keys
          records = records.where(_primary_key => primary_keys)
        end

        unless filters.empty?
          records = resource_klass.filter_records(records, filters, options)
        end

        if sort_primary
          records = records.order(_primary_key => :asc)
        else
          order_options = resource_klass.construct_order_options(sort_criteria)
          records = resource_klass.sort_records(records, order_options, options)
        end

        if paginator
          records = resource_klass.apply_pagination(records, paginator, order_options)
        end

        records
      end

      def apply_joins(records, join_manager, options)
        join_manager.join(records, options)
      end

      def apply_pagination(records, paginator, order_options)
        records = paginator.apply(records, order_options) if paginator
        records
      end

      def apply_sort(records, order_options, options)
        if order_options.any?
          order_options.each_pair do |field, direction|
            records = apply_single_sort(records, field, direction, options)
          end
        end

        records
      end

      def apply_single_sort(records, field, direction, options)
        context = options[:context]

        strategy = _allowed_sort.fetch(field.to_sym, {})[:apply]

        options[:_relation_helper_options] ||= {}
        options[:_relation_helper_options][:sort_fields] ||= []

        if strategy
          records = call_method_or_proc(strategy, records, direction, context)
        else
          join_manager = options.dig(:_relation_helper_options, :join_manager)
          sort_field = join_manager ? get_aliased_field(field, join_manager) : field
          options[:_relation_helper_options][:sort_fields].push("#{sort_field}")
          records = records.order(Arel.sql("#{sort_field} #{direction}"))
        end
        records
      end

      # Assumes ActiveRecord's counting. Override if you need a different counting method
      def count_records(records)
        if ::Rails::VERSION::MAJOR >= 6 || (::Rails::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR >= 1)
          records.count(:all)
        else
          records.count
        end
      end

      def filter_records(records, filters, options)
        if _polymorphic
          _polymorphic_resource_klasses.each do |klass|
            records = klass.apply_filters(records, filters, options)
          end
        else
          records = apply_filters(records, filters, options)
        end
        records
      end

      def construct_order_options(sort_params)
        if _polymorphic
          warn "Sorting is not supported on polymorphic relationships"
        else
          super(sort_params)
        end
      end

      def sort_records(records, order_options, options)
        apply_sort(records, order_options, options)
      end

      def sql_field_with_alias(table, field, quoted = true)
        Arel.sql("#{concat_table_field(table, field, quoted)} AS #{alias_table_field(table, field, quoted)}")
      end

      def sql_field_with_fixed_alias(table, field, alias_as,  quoted = true)
        Arel.sql("#{concat_table_field(table, field, quoted)} AS #{alias_as}")
      end

      def concat_table_field(table, field, quoted = false)
        if table.blank?
          split_table, split_field = field.to_s.split('.')
          if split_table && split_field
            table = split_table
            field = split_field
          end
        end
        if table.blank?
          # :nocov:
          if quoted
            quote_column_name(field)
          else
            field.to_s
          end
          # :nocov:
        else
          if quoted
            "#{quote_table_name(table)}.#{quote_column_name(field)}"
          else
            # :nocov:
            "#{table.to_s}.#{field.to_s}"
            # :nocov:
          end
        end
      end

      def alias_table_field(table, field, quoted = false)
        if table.blank? || field.to_s.include?('.')
          # :nocov:
          if quoted
            quote_column_name(field)
          else
            field.to_s
          end
          # :nocov:
        else
          if quoted
            # :nocov:
            quote_column_name("#{table.to_s}_#{field.to_s}")
            # :nocov:
          else
            "#{table.to_s}_#{field.to_s}"
          end
        end
      end

      def quote_table_name(table_name)
        if _model_class&.connection
          _model_class.connection.quote_table_name(table_name)
        else
          quote(table_name)
        end
      end

      def quote_column_name(column_name)
        return column_name if column_name == "*"
        if _model_class&.connection
          _model_class.connection.quote_column_name(column_name)
        else
          quote(column_name)
        end
      end

      # fallback quote identifier when database adapter not available
      def quote(field)
        %{"#{field.to_s}"}
      end

      def apply_filters(records, filters, options = {})
        if filters
          filters.each do |filter, value|
            records = apply_filter(records, filter, value, options)
          end
        end

        records
      end

      def get_aliased_field(path_with_field, join_manager)
        path = JSONAPI::Path.new(resource_klass: self, path_string: path_with_field)

        relationship_segment = path.segments[-2]
        field_segment = path.segments[-1]

        if relationship_segment
          join_details = join_manager.join_details[path.last_relationship]
          table_alias = join_details[:alias]
        else
          table_alias = self._table_name
        end

        concat_table_field(table_alias, field_segment.delegated_field_name)
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          records = call_method_or_proc(strategy, records, value, options)
        else
          join_manager = options.dig(:_relation_helper_options, :join_manager)
          field = join_manager ? get_aliased_field(filter, join_manager) : filter.to_s
          records = records.where(Arel.sql(field) => value)
        end

        records
      end

      def warn_about_unused_methods
        if ::Rails.env.development?
          if !caching? && implements_class_method?(:records_for_populate)
            warn "#{self}: The `records_for_populate` method is not used when caching is disabled."
          end
        end
      end

      def implements_class_method?(method_name)
        methods(false).include?(method_name)
      end
    end
  end
end
