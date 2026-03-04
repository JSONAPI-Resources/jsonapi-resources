# frozen_string_literal: true

module JSONAPI
  class Relationship
    attr_reader :acts_as_set, :foreign_key, :options, :name,
                :class_name, :polymorphic, :always_include_optional_linkage_data, :exclude_linkage_data,
                :parent_resource, :eager_load_on_include, :custom_methods,
                :inverse_relationship, :allow_include, :hidden, :use_related_resource_records_for_joins

    attr_writer :allow_include

    attr_accessor :_routed, :_warned_missing_route, :_warned_missing_inverse_relationship

    def initialize(name, options = {})
      @name = name.to_s
      @options = options
      @acts_as_set = options.fetch(:acts_as_set, false) == true
      @foreign_key = options[:foreign_key] ? options[:foreign_key].to_sym : nil
      @parent_resource = options[:parent_resource]
      @relation_name = options[:relation_name]
      @polymorphic = options.fetch(:polymorphic, false) == true
      @polymorphic_types_override = options[:polymorphic_types]

      if options[:polymorphic_relations]
        JSONAPI.configuration.deprecate('Use polymorphic_types instead of polymorphic_relations')
        @polymorphic_types_override ||= options[:polymorphic_relations]
      end

      use_related_resource_records_for_joins_default = if options[:relation_name]
                                                         false
                                                       else
                                                         JSONAPI.configuration.use_related_resource_records_for_joins
                                                       end

      @use_related_resource_records_for_joins = options.fetch(:use_related_resource_records_for_joins,
                                                              use_related_resource_records_for_joins_default) == true

      @hidden = options.fetch(:hidden, false) == true

      @exclude_linkage_data = options[:exclude_linkage_data]
      @always_include_optional_linkage_data = options.fetch(:always_include_optional_linkage_data, false) == true
      @eager_load_on_include = options.fetch(:eager_load_on_include, true) == true
      @allow_include = options[:allow_include]
      @class_name = nil

      @inverse_relationship = options[:inverse_relationship]&.to_sym

      @_routed = false
      @_warned_missing_route = false
      @_warned_missing_inverse_relationship = false

      exclude_links(options.fetch(:exclude_links, JSONAPI.configuration.default_exclude_links))

      # Custom methods are reserved for future use
      @custom_methods = options.fetch(:custom_methods, {})
    end

    alias_method :polymorphic?, :polymorphic
    alias_method :parent_resource_klass, :parent_resource

    def primary_key
      # :nocov:
      @primary_key ||= resource_klass._primary_key
      # :nocov:
    end

    def resource_klass
      @resource_klass ||= @parent_resource.resource_klass_for(@class_name)
    end

    def table_name
      # :nocov:
      @table_name ||= resource_klass._table_name
      # :nocov:
    end

    def inverse_relationship
      unless @inverse_relationship
        @inverse_relationship ||= if resource_klass._relationship(@parent_resource._type.to_s.singularize).present?
                                    @parent_resource._type.to_s.singularize.to_sym
                                  elsif resource_klass._relationship(@parent_resource._type).present?
                                    @parent_resource._type.to_sym
                                  else
                                    nil
                                  end
      end

      @inverse_relationship
    end

    def polymorphic_types
      return @polymorphic_types if @polymorphic_types

      types = @polymorphic_types_override
      types ||= ::JSONAPI::Utils::PolymorphicTypesLookup.polymorphic_types(_relation_name)

      @polymorphic_types = types&.map { |t| t.to_s.pluralize } || []

      if @polymorphic_types.blank?
        warn "[POLYMORPHIC TYPE] No polymorphic types set or found for #{parent_resource.name} #{_relation_name}"
      end

      @polymorphic_types
    end

    def resource_types
      @resource_types ||= if polymorphic?
                            polymorphic_types
                          else
                            [resource_klass._type.to_s.pluralize]
                          end
    end

    def type
      @type ||= resource_klass._type.to_sym
    end

    def relation_name(options)
      case _relation_name
      when Symbol
        # :nocov:
        _relation_name
        # :nocov:
      when String
        _relation_name.to_sym
      when Proc
        _relation_name.call(options)
      end
    end

    def belongs_to?
      # :nocov:
      false
      # :nocov:
    end

    def readonly?
      @options[:readonly]
    end

    def exclude_links(exclude)
      case exclude
      when :default, "default"
        @_exclude_links = [:self, :related]
      when :none, "none"
        @_exclude_links = []
      when Array
        @_exclude_links = exclude.collect { |link| link.to_sym }
      else
        fail "Invalid exclude_links"
      end
    end

    def _exclude_links
      @_exclude_links ||= []
    end

    def exclude_link?(link)
      _exclude_links.include?(link.to_sym)
    end

    def _relation_name
      @relation_name || @name
    end

    def to_s
      display_name
    end

    def _inverse_relationship
      @inverse_relationship_klass ||= self.resource_klass._relationship(self.inverse_relationship)
      if @inverse_relationship_klass.blank?
        message = "Missing inverse relationship detected for: #{self}"
        warn message if JSONAPI.configuration.warn_on_missing_relationships && !@_warned_missing_inverse_relationship
        @_warned_missing_inverse_relationship = true

        raise message if JSONAPI.configuration.raise_on_missing_relationships
      end
      @inverse_relationship_klass
    end

    class ToOne < Relationship
      attr_reader :foreign_key_on

      def initialize(name, options = {})
        super
        @class_name = options.fetch(:class_name, name.to_s.classify)
        @foreign_key ||= "#{name}_id".to_sym
        @foreign_key_on = options.fetch(:foreign_key_on, :self)
        # if parent_resource
        #   @inverse_relationship = options.fetch(:inverse_relationship, parent_resource._type)
        # end

        if options.fetch(:create_implicit_polymorphic_type_relationships, true) == true && polymorphic?
          # Setup the implicit relationships for the polymorphic types and exclude linkage data
          setup_implicit_relationships_for_polymorphic_types
        end

        @polymorphic_type_relationship_for = options[:polymorphic_type_relationship_for]
      end

      def display_name
        # :nocov: useful for debugging
        "#{parent_resource.name}.#{name}(#{belongs_to? ? 'BelongsToOne' : 'ToOne'})"
        # :nocov:
      end

      def belongs_to?
        # :nocov:
        foreign_key_on == :self
        # :nocov:
      end

      def hidden?
        @hidden || @polymorphic_type_relationship_for.present?
      end

      def polymorphic_type
        "#{name}_type" if polymorphic?
      end

      def setup_implicit_relationships_for_polymorphic_types(exclude_linkage_data: true)
        types = polymorphic_types

        types.each do |type|
          parent_resource.has_one(type.to_s.underscore.singularize,
                                  exclude_linkage_data: exclude_linkage_data,
                                  polymorphic_type_relationship_for: name)
        end
      end

      def include_optional_linkage_data?
        return false if @exclude_linkage_data
        @always_include_optional_linkage_data || JSONAPI::configuration.always_include_to_one_linkage_data
      end

      def allow_include?(context = nil)
        strategy = if @allow_include.nil?
                     JSONAPI.configuration.default_allow_include_to_one
                   else
                     @allow_include
                   end

        if !!strategy == strategy # check for boolean
          return strategy
        elsif strategy.is_a?(Symbol) || strategy.is_a?(String)
          parent_resource_klass.send(strategy, context)
        else
          strategy.call(context)
        end
      end
    end

    class ToMany < Relationship
      attr_reader :reflect

      def initialize(name, options = {})
        super
        @class_name = options.fetch(:class_name, name.to_s.classify)
        @foreign_key ||= "#{name.to_s.singularize}_ids".to_sym
        @reflect = options.fetch(:reflect, true) == true
        # if parent_resource
        #   @inverse_relationship = options.fetch(:inverse_relationship, parent_resource._type.to_s.singularize.to_sym)
        # end
      end

      def display_name
        # :nocov: useful for debugging
        "#{parent_resource.name}.#{name}(ToMany)"
        # :nocov:
      end

      def hidden?
        @hidden
      end

      def include_optional_linkage_data?
        # :nocov:
        @always_include_optional_linkage_data || JSONAPI::configuration.always_include_to_many_linkage_data
        # :nocov:
      end

      def allow_include?(context = nil)
        strategy = if @allow_include.nil?
                     JSONAPI.configuration.default_allow_include_to_many
                   else
                     @allow_include
                   end

        if !!strategy == strategy # check for boolean
          return strategy
        elsif strategy.is_a?(Symbol) || strategy.is_a?(String)
          parent_resource_klass.send(strategy, context)
        else
          strategy.call(context)
        end
      end

    end
  end
end
