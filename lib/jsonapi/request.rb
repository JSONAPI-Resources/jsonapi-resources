# frozen_string_literal: true

module JSONAPI
  class Request
    attr_accessor :fields, :include, :filters, :sort_criteria, :errors, :controller_module_path,
                  :context, :paginator, :source_klass, :source_id,
                  :include_directives, :params, :warnings, :server_error_callbacks, :operations

    def initialize(params = nil, options = {})
      @params = params
      if params
        controller_path = params.fetch(:controller, '')
        @controller_module_path = controller_path.include?('/') ? controller_path.rpartition('/').first + '/' : ''
      else
        @controller_module_path = ''
      end

      @context = options[:context]
      @key_formatter = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @errors = []
      @warnings = []
      @server_error_callbacks = options.fetch(:server_error_callbacks, [])
      @operations = []

      setup_operations(params)
    end

    def error_object_overrides
      {}
    end

    def transactional?
      case params[:action]
      when 'index', 'show_related_resource', 'index_related_resources', 'show', 'show_relationship'
        false
      else
        JSONAPI.configuration.allow_transactions
      end
    end

    def setup_operations(params)
      return if params.nil?

      resource_klass = Resource.resource_klass_for(params[:controller]) if params[:controller]

      setup_action_method_name = "setup_#{params[:action]}_action"
      if respond_to?(setup_action_method_name)
        raise params[:_parser_exception] if params[:_parser_exception]
        send(setup_action_method_name, params, resource_klass)
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param, error_object_overrides).errors)
    rescue JSONAPI::Exceptions::Error => e
      e.error_object_overrides.merge! error_object_overrides
      @errors.concat(e.errors)
    end

    def setup_index_action(params, resource_klass)
      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])
      filters = parse_filters(resource_klass, params[:filter])
      sort_criteria = parse_sort_criteria(resource_klass, params[:sort])
      paginator = parse_pagination(resource_klass, params[:page])

      @operations << JSONAPI::Operation.new(
        :find,
        resource_klass,
        context: context,
        filters: filters,
        include_directives: include_directives,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields
      )
    end

    def setup_show_related_resource_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      source_klass = Resource.resource_klass_for(params.require(:source))
      source_id = source_klass.verify_key(params.require(source_klass._as_parent_key), @context)

      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])

      relationship_type = params[:relationship].to_sym

      @operations << JSONAPI::Operation.new(
        :show_related_resource,
        resource_klass,
        context: @context,
        relationship_type: relationship_type,
        source_klass: source_klass,
        source_id: source_id,
        fields: fields,
        include_directives: include_directives
      )
    end

    def setup_index_related_resources_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      source_klass = Resource.resource_klass_for(params.require(:source))
      source_id = source_klass.verify_key(params.require(source_klass._as_parent_key), @context)

      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])
      filters = parse_filters(resource_klass, params[:filter])
      sort_criteria = parse_sort_criteria(resource_klass, params[:sort])
      paginator = parse_pagination(resource_klass, params[:page])
      relationship_type = params[:relationship]

      @operations << JSONAPI::Operation.new(
        :show_related_resources,
        resource_klass,
        context: @context,
        relationship_type: relationship_type,
        source_klass: source_klass,
        source_id: source_id,
        filters: filters,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        include_directives: include_directives
      )
    end

    def setup_show_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])
      id = params[:id]

      @operations << JSONAPI::Operation.new(
        :show,
        resource_klass,
        context: @context,
        id: id,
        include_directives: include_directives,
        fields: fields,
        allowed_resources: params[:allowed_resources]
      )
    end

    def setup_show_relationship_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      relationship_type = params[:relationship]
      parent_key = params.require(resource_klass._as_parent_key)
      include_directives = parse_include_directives(resource_klass, params[:include])
      filters = parse_filters(resource_klass, params[:filter])
      sort_criteria = parse_sort_criteria(resource_klass, params[:sort])
      paginator = parse_pagination(resource_klass, params[:page])

      @operations << JSONAPI::Operation.new(
        :show_relationship,
        resource_klass,
        context: @context,
        relationship_type: relationship_type,
        parent_key: resource_klass.verify_key(parent_key),
        filters: filters,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        include_directives: include_directives
      )
    end

    def setup_create_action(params, resource_klass)
      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])

      data = params.require(:data)

      unless data.respond_to?(:each_pair)
        fail JSONAPI::Exceptions::InvalidDataFormat.new(error_object_overrides)
      end

      verify_type(data[:type], resource_klass)

      data = parse_params(resource_klass, data, resource_klass.creatable_fields(@context))

      @operations << JSONAPI::Operation.new(
        :create_resource,
        resource_klass,
        context: @context,
        data: data,
        fields: fields,
        include_directives: include_directives,
        warnings: @warnings
      )
    end

    def setup_create_relationship_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      parse_modify_relationship_action(:add, params, resource_klass)
    end

    def setup_update_relationship_action(params, resource_klass)
      parse_modify_relationship_action(:update, params, resource_klass)
    end

    def setup_update_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])

      data = params.require(:data)
      key = params[:id]

      fail JSONAPI::Exceptions::InvalidDataFormat.new(error_object_overrides) unless data.respond_to?(:each_pair)

      fail JSONAPI::Exceptions::MissingKey.new(error_object_overrides) if data[:id].nil?

      resource_id = data.require(:id)
      # Singleton resources may not have the ID set in the URL
      if key
        fail JSONAPI::Exceptions::KeyNotIncludedInURL.new(resource_id) if key.to_s != resource_id.to_s
      end

      data.delete(:id)

      verify_type(data[:type], resource_klass)

      @operations << JSONAPI::Operation.new(
        :replace_fields,
        resource_klass,
        context: @context,
        resource_id: resource_id,
        data: parse_params(resource_klass, data, resource_klass.updatable_fields(@context)),
        fields: fields,
        include_directives: include_directives,
        warnings: @warnings
      )
    end

    def setup_destroy_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      @operations << JSONAPI::Operation.new(
        :remove_resource,
        resource_klass,
        context: @context,
        resource_id: resource_klass.verify_key(params.require(:id), @context))
    end

    def setup_destroy_relationship_action(params, resource_klass)
      resolve_singleton_id(params, resource_klass)
      parse_modify_relationship_action(:remove, params, resource_klass)
    end

    def parse_modify_relationship_action(modification_type, params, resource_klass)
      relationship_type = params.require(:relationship)

      parent_key = params.require(resource_klass._as_parent_key)
      relationship = resource_klass._relationship(relationship_type)

      # Removals of to-one relationships are done implicitly and require no specification of data
      data_required = !(modification_type == :remove && relationship.is_a?(JSONAPI::Relationship::ToOne))

      if data_required
        data = params.fetch(:data)
        object_params = { relationships: { format_key(relationship.name) => { data: data } } }

        verified_params = parse_params(resource_klass, object_params, resource_klass.updatable_fields(@context))

        parse_arguments = [resource_klass, verified_params, relationship, parent_key]
      else
        parse_arguments = [resource_klass, params, relationship, parent_key]
      end

      send(:"parse_#{modification_type}_relationship_operation", *parse_arguments)
    end

    def parse_pagination(resource_klass, page)
      paginator_name = resource_klass._paginator
      JSONAPI::Paginator.paginator_for(paginator_name).new(page) unless paginator_name == :none
    end

    def parse_fields(resource_klass, fields)
      extracted_fields = {}

      return extracted_fields if fields.nil?

      # Extract the fields for each type from the fields parameters
      if fields.is_a?(ActionController::Parameters)
        fields.each do |field, value|
          if value.is_a?(Array)
            resource_fields = value
          else
            resource_fields = value.split(',') unless value.nil? || value.empty?
          end
          extracted_fields[field] = resource_fields
        end
      else
        fail JSONAPI::Exceptions::InvalidFieldFormat.new(error_object_overrides)
      end

      # Validate the fields
      validated_fields = {}
      extracted_fields.each do |type, values|
        underscored_type = unformat_key(type)
        validated_fields[type] = []
        begin
          if type != format_key(type)
            fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
          end
          type_resource = Resource.resource_klass_for(resource_klass.module_path + underscored_type.to_s)
        rescue NameError
          fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
        end

        if type_resource.nil?
          fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
        else
          verify_type(type, type_resource)
          unless values.nil?
            valid_fields = type_resource.fields.collect { |key| format_key(key) }
            values.each do |field|
              if valid_fields.include?(field)
                validated_fields[type].push unformat_key(field)
              else
                fail JSONAPI::Exceptions::InvalidField.new(type, field, error_object_overrides)
              end
            end
          else
            fail JSONAPI::Exceptions::InvalidField.new(type, 'nil', error_object_overrides)
          end
        end
      end

      validated_fields.deep_transform_keys { |key| unformat_key(key) }
    end

    def check_include(resource_klass, include_parts)
      relationship_name = unformat_key(include_parts.first)

      relationship = resource_klass._relationship(relationship_name)
      if relationship && format_key(relationship_name) == include_parts.first
        unless relationship.allow_include?(context)
          fail JSONAPI::Exceptions::InvalidInclude.new(format_key(resource_klass._type), include_parts.first)
        end

        unless include_parts.last.empty?
          check_include(Resource.resource_klass_for(resource_klass.module_path + relationship.class_name.to_s.underscore),
                        include_parts.last.partition('.'))
        end
      else
        fail JSONAPI::Exceptions::InvalidInclude.new(format_key(resource_klass._type), include_parts.first)
      end
    end

    def parse_include_directives(resource_klass, raw_include)
      raw_include ||= ''

      included_resources = []
      begin
        included_resources += raw_include.is_a?(Array) ? raw_include : CSV.parse_line(raw_include) || []
      rescue CSV::MalformedCSVError
        fail JSONAPI::Exceptions::InvalidInclude.new(format_key(resource_klass._type), raw_include)
      end

      begin
        result = included_resources.compact.map do |included_resource|
          check_include(resource_klass, included_resource.partition('.'))
          unformat_key(included_resource).to_s
        end

        return JSONAPI::IncludeDirectives.new(resource_klass, result)
      rescue JSONAPI::Exceptions::InvalidInclude => e
        @errors.concat(e.errors)
        return {}
      end
    end

    def parse_filters(resource_klass, filters)
      parsed_filters = {}

      # apply default filters
      resource_klass._allowed_filters.each do |filter, opts|
        next if opts[:default].nil? || !parsed_filters[filter].nil?
        parsed_filters[filter] = opts[:default]
      end

      return parsed_filters unless filters

      unless filters.class.method_defined?(:each)
        @errors.concat(JSONAPI::Exceptions::InvalidFiltersSyntax.new(filters).errors)
        return {}
      end

      unless JSONAPI.configuration.allow_filter
        fail JSONAPI::Exceptions::ParameterNotAllowed.new(:filter)
      end

      filters.each do |key, value|
        filter = unformat_key(key)
        if resource_klass._allowed_filter?(filter)
          parsed_filters[filter] = value
        else
          fail JSONAPI::Exceptions::FilterNotAllowed.new(key)
        end
      end

      parsed_filters
    end

    def parse_sort_criteria(resource_klass, sort_criteria)
      return unless sort_criteria.present?

      unless JSONAPI.configuration.allow_sort
        fail JSONAPI::Exceptions::ParameterNotAllowed.new(:sort)
      end

      if sort_criteria.is_a?(Array)
        sorts = sort_criteria
      elsif sort_criteria.is_a?(String)
        begin
          raw = URI.decode_www_form_component(sort_criteria)
          sorts = CSV.parse_line(raw)
        rescue CSV::MalformedCSVError
          fail JSONAPI::Exceptions::InvalidSortCriteria.new(format_key(resource_klass._type), raw)
        end
      end

      @sort_criteria = sorts.collect do |sort|
        if sort.start_with?('-')
          criteria = { field: unformat_key(sort[1..-1]).to_s }
          criteria[:direction] = :desc
        else
          criteria = { field: unformat_key(sort).to_s }
          criteria[:direction] = :asc
        end

        check_sort_criteria(resource_klass, criteria)
        criteria
      end
    end

    def check_sort_criteria(resource_klass, sort_criteria)
      sort_field = sort_criteria[:field]

      unless resource_klass.sortable_field?(sort_field.to_sym, context)
        fail JSONAPI::Exceptions::InvalidSortCriteria.new(format_key(resource_klass._type), sort_field)
      end
    end

    def verify_type(type, resource_klass)
      if type.nil?
        fail JSONAPI::Exceptions::ParameterMissing.new(:type)
      elsif unformat_key(type).to_sym != resource_klass._type
        fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
      end
    end

    def parse_to_one_links_object(raw)
      if raw.nil?
        return {
          type: nil,
          id: nil
        }
      end

      if !(raw.is_a?(Hash) || raw.is_a?(ActionController::Parameters)) ||
        raw.keys.length != 2 || !(raw.key?('type') && raw.key?('id'))
        fail JSONAPI::Exceptions::InvalidLinksObject.new(error_object_overrides)
      end

      {
        type: unformat_key(raw['type']).to_s,
        id: raw['id']
      }
    end

    def parse_to_many_links_object(raw)
      fail JSONAPI::Exceptions::InvalidLinksObject.new(error_object_overrides) if raw.nil?

      links_object = {}
      if raw.is_a?(Array)
        raw.each do |link|
          link_object = parse_to_one_links_object(link)
          links_object[link_object[:type]] ||= []
          links_object[link_object[:type]].push(link_object[:id])
        end
      else
        fail JSONAPI::Exceptions::InvalidLinksObject.new(error_object_overrides)
      end
      links_object
    end

    def parse_params(resource_klass, params, allowed_fields)
      verify_permitted_params(params, allowed_fields)

      checked_attributes = {}
      checked_to_one_relationships = {}
      checked_to_many_relationships = {}

      params.each do |key, value|
        case key.to_s
        when 'relationships'
          value.each do |link_key, link_value|
            param = unformat_key(link_key)
            relationship = resource_klass._relationship(param)

            if relationship.is_a?(JSONAPI::Relationship::ToOne)
              checked_to_one_relationships[param] = parse_to_one_relationship(resource_klass, link_value, relationship)
            elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
              parse_to_many_relationship(resource_klass, link_value, relationship) do |result_val|
                checked_to_many_relationships[param] = result_val
              end
            end
          end
        when 'id'
          checked_attributes['id'] = unformat_value(resource_klass, :id, value)
        when 'attributes'
          value.each do |key, value|
            param = unformat_key(key)
            checked_attributes[param] = unformat_value(resource_klass, param, value)
          end
        end
      end

      {
        'attributes' => checked_attributes,
        'to_one' => checked_to_one_relationships,
        'to_many' => checked_to_many_relationships
      }.deep_transform_keys { |key| unformat_key(key) }
    end

    def parse_to_one_relationship(resource_klass, link_value, relationship)
      if link_value.nil?
        linkage = nil
      else
        linkage = link_value[:data]
      end

      links_object = parse_to_one_links_object(linkage)
      if !relationship.polymorphic? && links_object[:type] && (links_object[:type].to_s != relationship.type.to_s)
        fail JSONAPI::Exceptions::TypeMismatch.new(links_object[:type], error_object_overrides)
      end

      unless links_object[:id].nil?
        resource = resource_klass || Resource
        relationship_resource = resource.resource_klass_for(unformat_key(relationship.options[:class_name] || links_object[:type]).to_s)
        relationship_id = relationship_resource.verify_key(links_object[:id], @context)
        if relationship.polymorphic?
          { id: relationship_id, type: unformat_key(links_object[:type].to_s) }
        else
          relationship_id
        end
      else
        nil
      end
    end

    def parse_to_many_relationship(resource_klass, link_value, relationship, &add_result)
      if (link_value.is_a?(Hash) || link_value.is_a?(ActionController::Parameters))
        linkage = link_value[:data]
      else
        fail JSONAPI::Exceptions::InvalidLinksObject.new(error_object_overrides)
      end

      links_object = parse_to_many_links_object(linkage)

      if links_object.length == 0
        add_result.call([])
      else
        if relationship.polymorphic?
          polymorphic_results = []

          links_object.each_pair do |type, keys|
            type_name = unformat_key(type).to_s

            relationship_resource_klass = resource_klass.resource_klass_for(relationship.class_name)
            relationship_klass = relationship_resource_klass._model_class

            linkage_object_resource_klass = resource_klass.resource_klass_for(type_name)
            linkage_object_klass = linkage_object_resource_klass._model_class

            unless linkage_object_klass == relationship_klass || linkage_object_klass.in?(relationship_klass.subclasses)
              fail JSONAPI::Exceptions::TypeMismatch.new(type_name)
            end

            relationship_ids = relationship_resource_klass.verify_keys(keys, @context)
            polymorphic_results << { type: type, ids: relationship_ids }
          end

          add_result.call polymorphic_results
        else
          relationship_type = unformat_key(relationship.type).to_s

          if links_object.length > 1 || !links_object.has_key?(relationship_type)
            fail JSONAPI::Exceptions::TypeMismatch.new(links_object[:type])
          end

          relationship_resource_klass = Resource.resource_klass_for(resource_klass.module_path + relationship_type)
          add_result.call relationship_resource_klass.verify_keys(links_object[relationship_type], @context)
        end
      end
    end

    def unformat_value(resource_klass, attribute, value)
      value_formatter = JSONAPI::ValueFormatter.value_formatter_for(resource_klass._attribute_options(attribute)[:format])
      value_formatter.unformat(value)
    end

    def verify_permitted_params(params, allowed_fields)
      formatted_allowed_fields = allowed_fields.collect { |field| format_key(field).to_sym }
      params_not_allowed = []

      params.each do |key, value|
        case key.to_s
        when 'relationships'
          value.keys.each do |links_key|
            unless formatted_allowed_fields.include?(links_key.to_sym)
              if JSONAPI.configuration.raise_if_parameters_not_allowed
                fail JSONAPI::Exceptions::ParameterNotAllowed.new(links_key, error_object_overrides)
              else
                params_not_allowed.push(links_key)
                value.delete links_key
              end
            end
          end
        when 'attributes'
          value.each do |attr_key, _attr_value|
            unless formatted_allowed_fields.include?(attr_key.to_sym)
              if JSONAPI.configuration.raise_if_parameters_not_allowed
                fail JSONAPI::Exceptions::ParameterNotAllowed.new(attr_key, error_object_overrides)
              else
                params_not_allowed.push(attr_key)
                value.delete attr_key
              end
            end
          end
        when 'type'
        when 'id'
          unless formatted_allowed_fields.include?(:id)
            if JSONAPI.configuration.raise_if_parameters_not_allowed
              fail JSONAPI::Exceptions::ParameterNotAllowed.new(:id, error_object_overrides)
            else
              params_not_allowed.push(:id)
              params.delete :id
            end
          end
        else
          if JSONAPI.configuration.raise_if_parameters_not_allowed
            fail JSONAPI::Exceptions::ParameterNotAllowed.new(key, error_object_overrides)
          else
            params_not_allowed.push(key)
            params.delete key
          end
        end
      end

      if params_not_allowed.length > 0
        params_not_allowed_warnings = params_not_allowed.map do |param|
          JSONAPI::Warning.new(code: JSONAPI::PARAM_NOT_ALLOWED,
                               title: 'Param not allowed',
                               detail: "#{param} is not allowed.")
        end
        self.warnings.concat(params_not_allowed_warnings)
      end
    end

    def parse_add_relationship_operation(resource_klass, verified_params, relationship, parent_key)
      if relationship.is_a?(JSONAPI::Relationship::ToMany)
        @operations << JSONAPI::Operation.new(
          :create_to_many_relationships,
          resource_klass,
          context: @context,
          resource_id: parent_key,
          relationship_type: relationship.name,
          data: verified_params[:to_many].values[0]
        )
      end
    end

    def parse_update_relationship_operation(resource_klass, verified_params, relationship, parent_key)
      options = {
        context: @context,
        resource_id: parent_key,
        relationship_type: relationship.name
      }

      if relationship.is_a?(JSONAPI::Relationship::ToOne)
        if relationship.polymorphic?
          options[:key_value] = verified_params[:to_one].values[0][:id]
          options[:key_type] = verified_params[:to_one].values[0][:type]

          operation_type = :replace_polymorphic_to_one_relationship
        else
          options[:key_value] = verified_params[:to_one].values[0]
          operation_type = :replace_to_one_relationship
        end
      elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
        unless relationship.acts_as_set
          fail JSONAPI::Exceptions::ToManySetReplacementForbidden.new
        end
        options[:data] = verified_params[:to_many].values[0]
        operation_type = :replace_to_many_relationships
      end

      @operations << JSONAPI::Operation.new(operation_type, resource_klass, options)
    end

    def parse_remove_relationship_operation(resource_klass, params, relationship, parent_key)
      operation_base_args = [resource_klass].push(
        context: @context,
        resource_id: parent_key,
        relationship_type: relationship.name
      )

      if relationship.is_a?(JSONAPI::Relationship::ToMany)
        operation_args = operation_base_args.dup
        keys = params[:to_many].values[0]
        operation_args[1] = operation_args[1].merge(associated_keys: keys)
        @operations << JSONAPI::Operation.new(:remove_to_many_relationships, *operation_args)
      else
        @operations << JSONAPI::Operation.new(:remove_to_one_relationship, *operation_base_args)
      end
    end

    def resolve_singleton_id(params, resource_klass)
      if resource_klass.singleton? && params[:id].nil?
        key = resource_klass.singleton_key(context)
        params[:id] = key
      end
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def unformat_key(key)
      unformatted_key = @key_formatter.unformat(key)
      unformatted_key.nil? ? nil : unformatted_key.to_sym
    end
  end
end
