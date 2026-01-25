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
      false
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
