# frozen_string_literal: true

require 'jsonapi/configuration'

module JSONAPI
  class BasicResource
    @abstract = true
    @immutable = true
    @root = true

    attr_reader :context

    def initialize(model, context)
      @model = model
      @context = context
    end

    def _model
      @model
    end

    def id
      _model.public_send(self.class._primary_key)
    end

    def identity
      JSONAPI::ResourceIdentity.new(self.class, id)
    end

    def cache_field_value
      _model.public_send(self.class._cache_field)
    end

    def cache_id
      [id, self.class.hash_cache_field(cache_field_value)]
    end

    # Override this on a resource instance to override the fetchable keys
    def fetchable_fields
      self.class.fields
    end

    # Override this to return resource level meta data
    def meta(_options)
      {}
    end

    # Override this to return custom links
    def custom_links(_options)
      {}
    end

    class << self
      def inherited(subclass)
        super
        subclass.abstract(false)
        subclass.immutable(true)
        subclass.caching(_caching)
        subclass.cache_field(_cache_field) if @_cache_field
        subclass.singleton(singleton?, (_singleton_options.dup || {}))
        subclass.exclude_links(_exclude_links)
        subclass.paginator(@_paginator)
        subclass._attributes = (_attributes || {}).dup
        subclass.polymorphic(false)
        subclass.key_type(@_resource_key_type)

        subclass._model_hints = (_model_hints || {}).dup

        unless _model_name.empty?
          subclass.model_name(_model_name, add_model_hint: (_model_hints && !_model_hints[_model_name].nil?) == true)
        end

        subclass.rebuild_relationships(_relationships || {})

        subclass._allowed_filters = (_allowed_filters || Set.new).dup

        subclass._allowed_sort = _allowed_sort.dup

        type = subclass.name.demodulize.sub(/Resource$/, '').underscore
        subclass._type = type.pluralize.to_sym

        unless subclass._attributes[:id]
          subclass.attribute :id, format: :id, readonly: true
        end

        check_reserved_resource_name(subclass._type, subclass.name)

        subclass._routed = false
        subclass._warned_missing_route = false

        subclass._clear_cached_attribute_options
        subclass._clear_fields_cache
      end

      def rebuild_relationships(relationships)
        original_relationships = relationships.deep_dup

        @_relationships = {}

        if original_relationships.is_a?(Hash)
          original_relationships.each_value do |relationship|
            options = relationship.options.dup
            options[:parent_resource] = self
            options[:inverse_relationship] = relationship.inverse_relationship
            _add_relationship(relationship.class, relationship.name, options)
          end
        end
      end

      def resource_klass_for(type)
        type = type.underscore
        type_with_module = type.start_with?(module_path) ? type : module_path + type

        resource_name = _resource_name_from_type(type_with_module)
        resource = resource_name.safe_constantize if resource_name
        if resource.nil?
          fail NameError, "JSONAPI: Could not find resource '#{type}'. (Class #{resource_name} not found)"
        end

        resource
      end

      def resource_klass_for_model(model)
        resource_klass_for(resource_type_for(model))
      end

      def _resource_name_from_type(type)
        "#{type.to_s.underscore.singularize}_resource".camelize
      end

      def resource_type_for(model)
        model_name = model.class.to_s.underscore
        if _model_hints[model_name]
          _model_hints[model_name]
        else
          model_name.rpartition('/').last
        end
      end

      attr_accessor :_attributes, :_relationships, :_type, :_model_hints, :_routed, :_warned_missing_route
      attr_writer :_allowed_filters, :_paginator, :_allowed_sort

      def routing_options(options)
        @_routing_resource_options = options
      end

      def routing_resource_options
        @_routing_resource_options ||= {}
      end

      # Methods used in defining a resource class
      def attributes(*attrs)
        options = attrs.extract_options!.dup
        attrs.each do |attr|
          attribute(attr, options)
        end
      end

      def attribute(attribute_name, options = {})
        _clear_cached_attribute_options
        _clear_fields_cache

        attr = attribute_name.to_sym

        check_reserved_attribute_name(attr)
        check_duplicate_attribute_name(attr) if options[:format].nil?

        @_attributes ||= {}
        @_attributes[attr] = options
        define_method attr do
          @model.public_send(options[:delegate] ? options[:delegate].to_sym : attr)
        end unless method_defined?(attr)

        if options.fetch(:sortable, true) && !_has_sort?(attr)
          sort attr
        end
      end

      def attribute_to_model_field(attribute)
        field_name = if attribute == :_cache_field
                       _cache_field
                     else
                       attr = @_attributes[attribute]
                       attr && attr[:delegate] ? attr[:delegate].to_sym : attribute
                     end

        { name: field_name, type: _model_class.attribute_types[field_name.to_s] }
      end

      def cast_to_attribute_type(value, type)
        type.cast(value)
      end

      def default_attribute_options
        { format: :default }
      end

      def relationship(*attrs)
        options = attrs.extract_options!
        klass = case options[:to]
                when :one
                  Relationship::ToOne
                when :many
                  Relationship::ToMany
                else
                  fail ArgumentError.new('to: must be either :one or :many')
                end
        _add_relationship(klass, *attrs, options.except(:to))
      end

      def has_one(*attrs)
        _add_relationship(Relationship::ToOne, *attrs)
      end

      def has_many(*attrs)
        _add_relationship(Relationship::ToMany, *attrs)
      end

      def model_name(model, options = {})
        @model_class = nil
        @_model_name = model.to_sym

        model_hint(model: @_model_name, resource: self) unless options[:add_model_hint] == false

        rebuild_relationships(_relationships)
      end

      def model_hint(model: _model_name, resource: _type)
        resource_type = ((resource.is_a?(Class)) && (resource < JSONAPI::BasicResource)) ? resource._type : resource.to_s

        _model_hints[model.to_s.gsub('::', '/').underscore] = resource_type.to_s
      end

      def singleton(*attrs)
        @_singleton = (!!attrs[0] == attrs[0]) ? attrs[0] : true
        @_singleton_options = attrs.extract_options!
      end

      def _singleton_options
        @_singleton_options ||= {}
      end

      def singleton?
        @_singleton ||= false
      end

      def filters(*attrs)
        @_allowed_filters.merge!(attrs.inject({}) { |h, attr| h[attr] = {}; h })
      end

      def filter(attr, *args)
        @_allowed_filters[attr.to_sym] = args.extract_options!
      end

      def sort(sorting, options = {})
        self._allowed_sort[sorting.to_sym] = options
      end

      def sorts(*args)
        options = args.extract_options!
        _allowed_sort.merge!(args.inject({}) { |h, sorting| h[sorting.to_sym] = options.dup; h })
      end

      def primary_key(key)
        @_primary_key = key.to_sym
      end

      def cache_field(field)
        @_cache_field = field.to_sym
      end

      # Override in your resource to filter the sortable keys
      def sortable_fields(_context = nil)
        _allowed_sort.keys
      end

      def sortable_field?(key, context = nil)
        sortable_fields(context).include? key.to_sym
      end

      def fields
        @_fields_cache ||= _relationships.keys | _attributes.keys
      end

      def resources_for(records, context)
        records.collect do |record|
          resource_for(record, context)
        end
      end

      def resource_for(model_record, context)
        resource_klass = resource_klass_for_model(model_record)
        resource_klass.new(model_record, context)
      end

      def verify_filters(filters, context = nil)
        verified_filters = {}
        filters.each do |filter, raw_value|
          verified_filter = verify_filter(filter, raw_value, context)
          verified_filters[verified_filter[0]] = verified_filter[1]
        end
        verified_filters
      end

      def is_filter_relationship?(filter)
        filter == _type || _relationships.include?(filter)
      end

      def verify_filter(filter, raw, context = nil)
        filter_values = []
        if raw.present?
          begin
            filter_values += raw.is_a?(String) ? CSV.parse_line(raw) : [raw]
          rescue CSV::MalformedCSVError
            filter_values << raw
          end
        end

        strategy = _allowed_filters.fetch(filter, Hash.new)[:verify]

        if strategy
          values = call_method_or_proc(strategy, filter_values, context)
          [filter, values]
        else
          if is_filter_relationship?(filter)
            verify_relationship_filter(filter, filter_values, context)
          else
            verify_custom_filter(filter, filter_values, context)
          end
        end
      end

      def call_method_or_proc(strategy, *args)
        if strategy.is_a?(Symbol) || strategy.is_a?(String)
          send(strategy, *args)
        else
          strategy.call(*args)
        end
      end

      def key_type(key_type)
        @_resource_key_type = key_type
      end

      def resource_key_type
        @_resource_key_type || JSONAPI.configuration.resource_key_type
      end

      def singleton_key(context)
        if @_singleton_options && @_singleton_options[:singleton_key]
          strategy = @_singleton_options[:singleton_key]
          case strategy
          when Proc
            key = strategy.call(context)
          when Symbol, String
            key = send(strategy, context)
          else
            raise "singleton_key must be a proc or function name"
          end
        end
        key
      end

      def verify_key(key, context = nil)
        key_type = resource_key_type

        case key_type
        when :integer
          return if key.nil?

          Integer(key)
        when :string
          return if key.nil?
          if key.to_s.include?(',')
            raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
          else
            key
          end
        when :uuid
          return if key.nil?

          if key.to_s.match(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
            key
          else
            raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
          end
        else
          key_type.call(key, context)
        end
      rescue
        raise JSONAPI::Exceptions::InvalidFieldValue.new(:id, key)
      end

      def verify_keys(keys, context = nil)
        return keys.collect do |key|
          verify_key(key, context)
        end
      end

      def verify_custom_filter(filter, value, _context = nil)
        [filter, value]
      end

      def verify_relationship_filter(filter, raw, _context = nil)
        [filter, raw]
      end

      def _attribute_options(attr)
        @_cached_attribute_options[attr] ||= default_attribute_options.merge(@_attributes[attr])
      end

      def _attribute_delegated_name(attr)
        @_attributes.fetch(attr.to_sym, {}).fetch(:delegate, attr)
      end

      def _has_attribute?(attr)
        @_attributes.keys.include?(attr.to_sym)
      end

      def _relationship(type)
        return nil unless type

        type = type.to_sym
        @_relationships[type]
      end

      def _model_name
        if _abstract
          ''
        else
          return @_model_name.to_s if defined?(@_model_name)

          class_name = self.name
          return '' if class_name.nil?

          @_model_name = class_name.demodulize.sub(/Resource$/, '')
          @_model_name.to_s
        end
      end

      def _polymorphic_name
        if !_polymorphic
          ''
        else
          @_polymorphic_name ||= _model_name.to_s.underscore
        end
      end

      def _primary_key
        @_primary_key ||= _default_primary_key
      end

      def _default_primary_key
        @_default_primary_key ||= _model_class.respond_to?(:primary_key) ? _model_class.primary_key : :id
      end

      def _cache_field
        @_cache_field || JSONAPI.configuration.default_resource_cache_field
      end

      def _table_name
        @_table_name ||= _model_class.respond_to?(:table_name) ? _model_class.table_name : _model_name.tableize
      end

      def _as_parent_key
        @_as_parent_key ||= "#{_type.to_s.singularize}_id"
      end

      def _allowed_filters
        defined?(@_allowed_filters) ? @_allowed_filters : { id: {} }
      end

      def _allowed_sort
        @_allowed_sort ||= {}
      end

      def _paginator
        @_paginator || JSONAPI.configuration.default_paginator
      end

      def paginator(paginator)
        @_paginator = paginator
      end

      def _polymorphic
        @_polymorphic
      end

      def polymorphic(polymorphic = true)
        @_polymorphic = polymorphic
      end

      def _polymorphic_types
        @poly_hash ||= {}.tap do |hash|
          ObjectSpace.each_object do |klass|
            next unless Module === klass

            if klass < ActiveRecord::Base
              klass.reflect_on_all_associations(:has_many).select { |r| r.options[:as] }.each do |reflection|
                (hash[reflection.options[:as]] ||= []) << klass.name.underscore
              end
            end
          end
        end
        @poly_hash[_polymorphic_name.to_sym]
      end

      def _polymorphic_resource_klasses
        @_polymorphic_resource_klasses ||= _polymorphic_types.collect do |type|
          resource_klass_for(type)
        end
      end

      def root_resource
        @abstract = true
        @immutable = true
        @root = true
      end

      def root?
        @root
      end

      def abstract(val = true)
        @abstract = val
      end

      def _abstract
        @abstract
      end

      def immutable(val = true)
        @immutable = val
      end

      def _immutable
        @immutable
      end

      def mutable?
        false
      end

      def parse_exclude_links(exclude)
        case exclude
        when :default, "default"
          [:self]
        when :none, "none"
          []
        when Array
          exclude.collect { |link| link.to_sym }
        else
          fail "Invalid exclude_links"
        end
      end

      def exclude_links(exclude)
        @_exclude_links = parse_exclude_links(exclude)
      end

      def _exclude_links
        @_exclude_links ||= parse_exclude_links(JSONAPI.configuration.default_exclude_links)
      end

      def exclude_link?(link)
        _exclude_links.include?(link.to_sym)
      end

      def caching(val = true)
        @caching = val
      end

      def _caching
        @caching
      end

      def caching?
        if @caching.nil?
          !JSONAPI.configuration.resource_cache.nil? && JSONAPI.configuration.default_caching
        else
          @caching && !JSONAPI.configuration.resource_cache.nil?
        end
      end

      def attribute_caching_context(_context)
        nil
      end

      def hash_cache_field(value)
        value.hash
      end

      def _model_class
        return nil if _abstract

        return @model_class if @model_class

        model_name = _model_name
        return nil if model_name.to_s.blank?

        @model_class = model_name.to_s.safe_constantize
        if @model_class.nil?
          warn "[MODEL NOT FOUND] Model could not be found for #{self.name}. If this is a base Resource declare it as abstract."
        end

        @model_class
      end

      def _allowed_filter?(filter)
        !_allowed_filters[filter].nil?
      end

      def _has_sort?(sorting)
        !_allowed_sort[sorting.to_sym].nil?
      end

      def module_path
        if name == 'JSONAPI::Resource'
          ''
        else
          name =~ /::[^:]+\Z/ ? ($`.freeze.gsub('::', '/') + '/').underscore : ''
        end
      end

      def default_sort
        [{ field: 'id', direction: :asc }]
      end

      def construct_order_options(sort_params)
        sort_params = default_sort if sort_params.blank?

        return {} unless sort_params

        sort_params.each_with_object({}) do |sort, order_hash|
          field = sort[:field].to_s == 'id' ? _primary_key : sort[:field].to_s
          order_hash[field] = sort[:direction]
        end
      end

      def _add_relationship(klass, *attrs)
        _clear_fields_cache

        options = attrs.extract_options!
        options[:parent_resource] = self

        attrs.each do |name|
          relationship_name = name.to_sym
          check_reserved_relationship_name(relationship_name)
          check_duplicate_relationship_name(relationship_name)

          define_relationship_methods(relationship_name.to_sym, klass, options)
        end
      end

      def define_relationship_methods(relationship_name, relationship_klass, options)
        register_relationship(
          relationship_name,
          relationship_klass.new(relationship_name, options)
        )
      end

      def define_on_resource(method_name, &block)
        return if method_defined?(method_name)

        define_method(method_name, block)
      end

      def register_relationship(name, relationship_object)
        @_relationships[name] = relationship_object
      end

      def _clear_cached_attribute_options
        @_cached_attribute_options = {}
      end

      def _clear_fields_cache
        @_fields_cache = nil
      end

      private

      def check_reserved_resource_name(type, name)
        if [:ids, :types, :hrefs, :links].include?(type)
          warn "[NAME COLLISION] `#{name}` is a reserved resource name."
          return
        end
      end

      def check_reserved_attribute_name(name)
        if [:type, :_cache_field, :cache_field].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved key in #{_resource_name_from_type(_type)}."
        end
      end

      def check_reserved_relationship_name(name)
        if [:id, :ids, :type, :types].include?(name.to_sym)
          warn "[NAME COLLISION] `#{name}` is a reserved relationship name in #{_resource_name_from_type(_type)}."
        end
      end

      def check_duplicate_relationship_name(name)
        if _relationships.include?(name.to_sym)
          warn "[DUPLICATE RELATIONSHIP] `#{name}` has already been defined in #{_resource_name_from_type(_type)}."
        end
      end

      def check_duplicate_attribute_name(name)
        if _attributes.include?(name.to_sym)
          warn "[DUPLICATE ATTRIBUTE] `#{name}` has already been defined in #{_resource_name_from_type(_type)}."
        end
      end
    end
  end
end
