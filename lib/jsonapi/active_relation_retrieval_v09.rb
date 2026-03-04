# frozen_string_literal: true

module JSONAPI
  module ActiveRelationRetrievalV09
    include ::JSONAPI::RelationRetrieval

    def find_related_ids(relationship, options = {})
      self.class.find_related_fragments(self.fragment, relationship, options).keys.collect { |rid| rid.id }
    end

    # Override this on a resource to customize how the associated records
    # are fetched for a model. Particularly helpful for authorization.
    def records_for(relation_name)
      _model.public_send relation_name
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
        context = options[:context]

        records = filter_records(records(options), filters, options)

        sort_criteria = options.fetch(:sort_criteria) { [] }
        order_options = construct_order_options(sort_criteria)
        records = sort_records(records, order_options, context)

        records = apply_pagination(records, options[:paginator], order_options)

        resources_for(records, context)
      end

      # Counts Resources found using the `filters`
      #
      # @param filters [Hash] the filters hash
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count
      def count(filters, options = {})
        count_records(filter_records(records(options), filters, options))
      end

      # Returns the single Resource identified by `key`
      #
      # @param key the primary key of the resource to find
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_key(key, options = {})
        context = options[:context]
        records = records(options)

        records = apply_includes(records, options)
        model = records.where({_primary_key => key}).first
        fail JSONAPI::Exceptions::RecordNotFound.new(key) if model.nil?
        self.resource_klass_for_model(model).new(model, context)
      end

      # Returns an array of Resources identified by the `keys` array
      #
      # @param keys [Array<key>] Array of primary keys to find resources for
      # @option options [Hash] :context The context of the request, set in the controller
      def find_by_keys(keys, options = {})
        context = options[:context]
        records = records(options)
        records = apply_includes(records, options)
        models = records.where({_primary_key => keys})
        models.collect do |model|
          self.resource_klass_for_model(model).new(model, context)
        end
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
        context = options[:context]

        sort_criteria = options.fetch(:sort_criteria) { [] }
        order_options = construct_order_options(sort_criteria)

        join_manager = ActiveRelation::JoinManager.new(resource_klass: self,
                                                       filters: filters,
                                                       sort_criteria: sort_criteria)

        options[:_relation_helper_options] = {
          context: context,
          join_manager: join_manager,
          sort_fields: []
        }

        include_directives = options[:include_directives]

        records = records(options)

        records = apply_joins(records, join_manager, options)

        records = filter_records(records, filters, options)

        records = sort_records(records, order_options, options)

        records = apply_pagination(records, options[:paginator], order_options)

        resources = resources_for(records, context)

        fragments = {}

        linkage_relationships = to_one_relationships_for_linkage(include_directives.try(:[], :include_related))

        resources.each do |resource|
          rid = resource.identity

          cache = options[:cache] ? resource.cache_field_value : nil

          fragment = JSONAPI::ResourceFragment.new(rid, resource: resource, cache: cache, primary: true)
          complete_linkages(fragment, linkage_relationships)
          fragments[rid] ||= fragment
        end

        fragments
      end

      # Finds Resource Fragments related to the source resources through the specified relationship
      #
      # @param source_fragment [ResourceFragment>] The resource to find related ResourcesFragments for
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      # @option options [Boolean] :cache Return the resources' cache field
      #
      # @return [Hash{ResourceIdentity => {identity: => ResourceIdentity, cache: cache_field, related: {relationship_name: [] }}}]
      #    the ResourceInstances matching the filters, sorting, and pagination rules along with any request
      #    additional_field values
      def find_related_fragments(source_fragment, relationship, options)
        fragments = {}
        include_directives = options[:include_directives]

        resource_klass = relationship.resource_klass

        linkage_relationships = resource_klass.to_one_relationships_for_linkage(include_directives.try(:[], :include_related))

        resources = source_fragment.resource.send(relationship.name, options)
        resources = [] if resources.nil?
        resources = [resources] unless resources.is_a?(Array)

        # Do not pass in source as it will setup linkage data to the source
        load_resources_to_fragments(fragments, resources, nil, relationship, linkage_relationships, options)

        fragments
      end

      def find_included_fragments(source_fragments, relationship, options)
        fragments = {}
        include_directives = options[:include_directives]
        resource_klass = relationship.resource_klass

        linkage_relationships = if relationship.polymorphic?
                                  []
                                else
                                  resource_klass.to_one_relationships_for_linkage(include_directives.try(:[], :include_related))
                                end

        source_fragments.each do |source_fragment|
          raise "Missing resource in fragment #{__callee__}" unless source_fragment.resource.present?

          resources = source_fragment.resource.send(relationship.name, options.except(:sort_criteria))
          resources = [] if resources.nil?
          resources = [resources] unless resources.is_a?(Array)

          load_resources_to_fragments(fragments, resources, source_fragment, relationship, linkage_relationships, options)
        end

        fragments
      end

      def find_related_fragments_from_inverse(source, source_relationship, options, connect_source_identity)
        raise "Not Implemented #{__callee__}"
      end

      # Counts Resources related to the source resource through the specified relationship
      #
      # @param source_rid [ResourceIdentity] Source resource identifier
      # @param relationship_name [String | Symbol] The name of the relationship
      # @option options [Hash] :context The context of the request, set in the controller
      #
      # @return [Integer] the count

      def count_related(source, relationship, options = {})
        opts = options.except(:paginator)

        related_resource_records = source.public_send("records_for_#{relationship.name}",
                                                      opts)
        count_records(related_resource_records)
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

      def load_resources_to_fragments(fragments, related_resources, source_resource, source_relationship, linkage_relationships, options)
        cached = options[:cache]
        primary = source_resource.nil?

        related_resources.each do |related_resource|
          cache = cached ? related_resource.cache_field_value : nil

          fragment = fragments[related_resource.identity]

          if fragment.nil?
            fragment = JSONAPI::ResourceFragment.new(related_resource.identity,
                                          resource: related_resource,
                                          cache: cache,
                                          primary: primary)

            fragments[related_resource.identity] = fragment
            complete_linkages(fragment, linkage_relationships)
          end

          if source_resource
            source_resource.add_related_identity(source_relationship.name, related_resource.identity)
            fragment.add_related_from(source_resource.identity)

            inverse_relationship = source_relationship._inverse_relationship
            fragment.add_related_identity(inverse_relationship.name, source_resource.identity) if inverse_relationship.present?
          end
        end
      end

      def complete_linkages(fragment, linkage_relationships)
        linkage_relationships.each do |linkage_relationship|
          related_id = fragment.resource._model.attributes[linkage_relationship.foreign_key.to_s]

          related_rid = if related_id
                          if linkage_relationship.polymorphic?
                            related_type = fragment.resource._model.attributes[linkage_relationship.polymorphic_type]
                            JSONAPI::ResourceIdentity.new(Resource.resource_klass_for(related_type), related_id)
                          else
                            klass = linkage_relationship.resource_klass
                            JSONAPI::ResourceIdentity.new(klass, related_id)
                          end
                        else
                          nil
                        end

          fragment.add_related_identity(linkage_relationship.name, related_rid)
        end
      end

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

      def define_relationship_methods(relationship_name, relationship_klass, options)
        foreign_key = super

        relationship = _relationship(relationship_name)

        case relationship
        when JSONAPI::Relationship::ToOne
          associated = define_resource_relationship_accessor(:one, relationship_name)
          args = [relationship, foreign_key, associated, relationship_name]

          relationship.belongs_to? ? build_belongs_to(*args) : build_has_one(*args)
        when JSONAPI::Relationship::ToMany
          associated = define_resource_relationship_accessor(:many, relationship_name)

          build_to_many(relationship, foreign_key, associated, relationship_name)
        end
      end


      def define_resource_relationship_accessor(type, relationship_name)
        associated_records_method_name = {
          one:  "record_for_#{relationship_name}",
          many: "records_for_#{relationship_name}"
        }.fetch(type)

        define_on_resource associated_records_method_name do |options = {}|
          relationship = self.class._relationships[relationship_name]
          relation_name = relationship.relation_name(context: @context)
          records = records_for(relation_name)

          resource_klass = relationship.resource_klass

          include_directives = options[:include_directives]&.include_directives&.dig(relationship_name)

          options = options.dup
          options[:include_directives] = include_directives

          records = resource_klass.apply_includes(records, options)

          filters = options.fetch(:filters, {})
          unless filters.nil? || filters.empty?
            records = resource_klass.apply_filters(records, filters, options)
          end

          sort_criteria =  options.fetch(:sort_criteria, {})
          order_options = relationship.resource_klass.construct_order_options(sort_criteria)
          records = resource_klass.apply_sort(records, order_options, options)

          paginator = options[:paginator]
          if paginator
            records = resource_klass.apply_pagination(records, paginator, order_options)
          end

          records
        end

        associated_records_method_name
      end

      def build_belongs_to(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Calls method matching foreign key name on model instance
        define_on_resource foreign_key do
          @model.method(foreign_key).call
        end

        # Returns instantiated related resource object or nil
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          if relationship.polymorphic?
            associated_model = public_send(associated_records_method_name)
            resource_klass = self.class.resource_klass_for_model(associated_model) if associated_model
            return resource_klass.new(associated_model, @context) if resource_klass
          else
            resource_klass = relationship.resource_klass
            if resource_klass
              associated_model = public_send(associated_records_method_name)
              return associated_model ? resource_klass.new(associated_model, @context) : nil
            end
          end
        end
      end

      def build_has_one(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Returns primary key name of related resource class
        define_on_resource foreign_key do
          relationship = self.class._relationships[relationship_name]

          record = public_send(associated_records_method_name)
          return nil if record.nil?
          record.public_send(relationship.resource_klass._primary_key)
        end

        # Returns instantiated related resource object or nil
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          if relationship.polymorphic?
            associated_model = public_send(associated_records_method_name)
            resource_klass = self.class.resource_klass_for_model(associated_model) if associated_model
            return resource_klass.new(associated_model, @context) if resource_klass && associated_model
          else
            resource_klass = relationship.resource_klass
            if resource_klass
              associated_model = public_send(associated_records_method_name)
              return associated_model ? resource_klass.new(associated_model, @context) : nil
            end
          end
        end
      end

      def build_to_many(relationship, foreign_key, associated_records_method_name, relationship_name)
        # Returns array of primary keys of related resource classes
        define_on_resource foreign_key do
          records = public_send(associated_records_method_name)
          return records.collect do |record|
            record.public_send(relationship.resource_klass._primary_key)
          end
        end

        # Returns array of instantiated related resource objects
        define_on_resource relationship_name do |options = {}|
          relationship = self.class._relationships[relationship_name]

          resource_klass = relationship.resource_klass
          records = public_send(associated_records_method_name, options)

          return records.collect do |record|
            if relationship.polymorphic?
              resource_klass = self.class.resource_for_model(record)
            end
            resource_klass.new(record, @context)
          end
        end
      end

      def resolve_relationship_names_to_relations(resource_klass, model_includes, options = {})
        case model_includes
        when Array
          return model_includes.map do |value|
            resolve_relationship_names_to_relations(resource_klass, value, options)
          end
        when Hash
          model_includes.keys.each do |key|
            relationship = resource_klass._relationships[key]
            value = model_includes[key]
            model_includes.delete(key)
            model_includes[relationship.relation_name(options)] = resolve_relationship_names_to_relations(relationship.resource_klass, value, options)
          end
          return model_includes
        when Symbol
          relationship = resource_klass._relationships[model_includes]
          return relationship.relation_name(options)
        end
      end

      def apply_includes(records, options = {})
        include_directives = options[:include_directives]
        if include_directives
          model_includes = resolve_relationship_names_to_relations(self, include_directives.model_includes, options)
          records = records.includes(model_includes)
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
        strategy = _allowed_sort.fetch(field.to_sym, {})[:apply]

        delegated_field = attribute_to_model_field(field)

        options[:_relation_helper_options] ||= {}
        options[:_relation_helper_options][:sort_fields] ||= []

        if strategy
          records = call_method_or_proc(strategy, records, direction, options)
        else
          join_manager = options.dig(:_relation_helper_options, :join_manager)
          sort_field = join_manager ? get_aliased_field(delegated_field[:name], join_manager) : delegated_field[:name]
          options[:_relation_helper_options][:sort_fields].push("#{sort_field}")
          records = records.order(Arel.sql("#{sort_field} #{direction}"))
        end
        records
      end

      def _lookup_association_chain(model_names)
        associations = []
        model_names.inject do |prev, current|
          association = prev.classify.constantize.reflect_on_all_associations.detect do |assoc|
            assoc.name.to_s.underscore == current.underscore
          end
          associations << association
          association.class_name
        end

        associations
      end

      def _build_joins(associations)
        joins = []

        associations.inject do |prev, current|
          joins << "LEFT JOIN #{current.table_name} AS #{current.name}_sorting ON #{current.name}_sorting.id = #{prev.table_name}.#{current.foreign_key}"
          current
        end
        joins.join("\n")
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

      def apply_filters(records, filters, options = {})
        # required_includes = []

        if filters
          filters.each do |filter, value|
            if _relationships.include?(filter) && _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply].blank?
              if _relationships[filter].belongs_to?
                records = apply_filter(records, _relationships[filter].foreign_key, value, options)
              else
                # required_includes.push(filter.to_s)
                records = apply_filter(records, "#{_relationships[filter].table_name}.#{_relationships[filter].primary_key}", value, options)
              end
            else
              records = apply_filter(records, filter, value, options)
            end
          end
        end

        # if required_includes.any?
        #   records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(self, required_includes, force_eager_load: true)))
        # end

        records
      end

      def filter_records(records, filters, options)
        records = apply_filters(records, filters, options)
        apply_includes(records, options)
      end

      def construct_order_options(sort_params)
        sort_params ||= default_sort

        return {} unless sort_params

        sort_params.each_with_object({}) do |sort, order_hash|
          field = sort[:field].to_s == 'id' ? _primary_key : sort[:field].to_s
          order_hash[field] = sort[:direction]
        end
      end

      def sort_records(records, order_options, options = {})
        apply_sort(records, order_options, options)
      end

      # Assumes ActiveRecord's counting. Override if you need a different counting method
      def count_records(records)
        records.count(:all)
      end

      def find_count(filters, options = {})
        count_records(filter_records(records(options), filters, options))
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
