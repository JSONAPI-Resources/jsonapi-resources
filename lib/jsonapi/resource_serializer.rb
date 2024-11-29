module JSONAPI
  class ResourceSerializer

    attr_reader :link_builder, :key_formatter, :serialization_options, :primary_class_name,
                :fields, :include_directives, :always_include_to_one_linkage_data,
                :always_include_to_many_linkage_data

    # initialize
    # Options can include
    # include:
    #     Purpose: determines which objects will be side loaded with the source objects in a linked section
    #     Example: ['comments','author','comments.tags','author.posts']
    # fields:
    #     Purpose: determines which fields are serialized for a resource type. This encompasses both attributes and
    #              relationship ids in the links section for a resource. Fields are global for a resource type.
    #     Example: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
    # key_formatter: KeyFormatter instance to override the default configuration
    # serialization_options: additional options that will be passed to resource meta and links lambdas

    def initialize(primary_resource_klass, options = {})
      @primary_resource_klass = primary_resource_klass
      @primary_class_name     = primary_resource_klass._type
      @fields                 = options.fetch(:fields, {})
      @include                = options.fetch(:include, [])
      @include_directives     = options[:include_directives]
      @include_directives     ||= JSONAPI::IncludeDirectives.new(@primary_resource_klass, @include)
      @key_formatter          = options.fetch(:key_formatter, JSONAPI.configuration.key_formatter)
      @id_formatter           = ValueFormatter.value_formatter_for(:id)
      @link_builder           = generate_link_builder(primary_resource_klass, options)
      @always_include_to_one_linkage_data = options.fetch(:always_include_to_one_linkage_data,
                                                          JSONAPI.configuration.always_include_to_one_linkage_data)
      @always_include_to_many_linkage_data = options.fetch(:always_include_to_many_linkage_data,
                                                           JSONAPI.configuration.always_include_to_many_linkage_data)
      @serialization_options = options.fetch(:serialization_options, {})

      # Warning: This makes ResourceSerializer non-thread-safe. That's not a problem with the
      # request-specific way it's currently used, though.
      @value_formatter_type_cache = NaiveCache.new{|arg| ValueFormatter.value_formatter_for(arg) }

      @_config_keys = {}
      @_supplying_attribute_fields = {}
      @_supplying_relationship_fields = {}
    end

    # Converts a single resource, or an array of resources to a hash, conforming to the JSONAPI structure
    def serialize_to_hash(source)
      @top_level_sources = Set.new([source].flatten(1).compact.map {|s| top_level_source_key(s) })

      is_resource_collection = source.respond_to?(:to_ary)

      @included_objects = {}

      process_source_objects(source, @include_directives.include_directives)

      primary_objects = []

      # pull the processed objects corresponding to the source objects. Ensures we preserve order.
      if is_resource_collection
        source.each do |primary|
          if primary.id
            case primary
              when CachedResourceFragment then primary_objects.push(@included_objects[primary.type][primary.id][:object_hash])
              when Resource then primary_objects.push(@included_objects[primary.class._type][primary.id][:object_hash])
              else raise "Unknown source type #{primary.inspect}"
            end
          end
        end
      else
        if source.try(:id)
          case source
            when CachedResourceFragment then primary_objects.push(@included_objects[source.type][source.id][:object_hash])
            when Resource then primary_objects.push(@included_objects[source.class._type][source.id][:object_hash])
            else raise "Unknown source type #{source.inspect}"
          end
        end
      end

      included_objects = []
      @included_objects.each_value do |objects|
        objects.each_value do |object|
          unless object[:primary]
            included_objects.push(object[:object_hash])
          end
        end
      end

      primary_hash = { data: is_resource_collection ? primary_objects : primary_objects[0] }

      primary_hash[:included] = included_objects if included_objects.size > 0
      primary_hash
    end

    def serialize_to_relationship_hash(source, requested_relationship)
      if requested_relationship.is_a?(JSONAPI::Relationship::ToOne)
        data = to_one_linkage(source, requested_relationship)
      else
        data = to_many_linkage(source, requested_relationship)
      end

      rel_hash = { 'data': data }

      links = default_relationship_links(source, requested_relationship)
      rel_hash['links'] = links unless links.blank?

      rel_hash
    end

    def query_link(query_params)
      link_builder.query_link(query_params)
    end

    def format_key(key)
      @key_formatter.format(key)
    end

    def format_value(value, format)
      @value_formatter_type_cache.get(format).format(value)
    end

    def config_key(resource_klass)
      @_config_keys.fetch resource_klass do
        desc = self.config_description(resource_klass).map(&:inspect).join(",")
        key = JSONAPI.configuration.resource_cache_digest_function.call(desc)
        @_config_keys[resource_klass] = "SRLZ-#{key}"
      end
    end

    def config_description(resource_klass)
      {
        class_name: self.class.name,
        seriserialization_options: serialization_options.sort.map(&:as_json),
        supplying_attribute_fields: supplying_attribute_fields(resource_klass).sort,
        supplying_relationship_fields: supplying_relationship_fields(resource_klass).sort,
        link_builder_base_url: link_builder.base_url,
        key_formatter_class: key_formatter.uncached.class.name,
        always_include_to_one_linkage_data: always_include_to_one_linkage_data,
        always_include_to_many_linkage_data: always_include_to_many_linkage_data
      }
    end

    # Returns a serialized hash for the source model
    def object_hash(source, include_directives = {})
      obj_hash = {}

      if source.is_a?(JSONAPI::CachedResourceFragment)
        obj_hash['id'] = source.id
        obj_hash['type'] = source.type

        obj_hash['links'] = source.links_json if source.links_json
        obj_hash['attributes'] = source.attributes_json if source.attributes_json

        relationships = cached_relationships_hash(source, include_directives)
        obj_hash['relationships'] = relationships unless relationships.blank?

        obj_hash['meta'] = source.meta_json if source.meta_json
      else
        fetchable_fields = Set.new(source.fetchable_fields)

        # TODO Should this maybe be using @id_formatter instead, for consistency?
        id_format = source.class._attribute_options(:id)[:format]
        # protect against ids that were declared as an attribute, but did not have a format set.
        id_format = 'id' if id_format == :default
        obj_hash['id'] = format_value(source.id, id_format)

        obj_hash['type'] = format_key(source.class._type.to_s)

        links = links_hash(source)
        obj_hash['links'] = links unless links.empty?

        attributes = attributes_hash(source, fetchable_fields)
        obj_hash['attributes'] = attributes unless attributes.empty?

        relationships = relationships_hash(source, fetchable_fields, include_directives)
        obj_hash['relationships'] = relationships unless relationships.blank?

        meta = meta_hash(source)
        obj_hash['meta'] = meta unless meta.empty?
      end

      obj_hash
    end

    private

    # Process the primary source object(s). This will then serialize associated object recursively based on the
    # requested includes. Fields are controlled fields option for each resource type, such
    # as fields: { people: [:id, :email, :comments], posts: [:id, :title, :author], comments: [:id, :body, :post]}
    # The fields options controls both fields and included links references.
    def process_source_objects(source, include_directives)
      if source.respond_to?(:to_ary)
        source.each { |resource| process_source_objects(resource, include_directives) }
      else
        return {} if source.nil?
        add_resource(source, include_directives, true)
      end
    end

    def supplying_attribute_fields(resource_klass)
      @_supplying_attribute_fields.fetch resource_klass do
        attrs = Set.new(resource_klass._attributes.keys.map(&:to_sym))
        cur = resource_klass
        while cur != JSONAPI::Resource
          if @fields.has_key?(cur._type)
            attrs &= @fields[cur._type]
            break
          end
          cur = cur.superclass
        end
        @_supplying_attribute_fields[resource_klass] = attrs
      end
    end

    def supplying_relationship_fields(resource_klass)
      @_supplying_relationship_fields.fetch resource_klass do
        relationships = Set.new(resource_klass._relationships.keys.map(&:to_sym))
        cur = resource_klass
        while cur != JSONAPI::Resource
          if @fields.has_key?(cur._type)
            relationships &= @fields[cur._type]
            break
          end
          cur = cur.superclass
        end
        @_supplying_relationship_fields[resource_klass] = relationships
      end
    end

    def attributes_hash(source, fetchable_fields)
      fields = fetchable_fields & supplying_attribute_fields(source.class)
      fields.each_with_object({}) do |name, hash|
        unless name == :id
          format = source.class._attribute_options(name)[:format]
          hash[format_key(name)] = format_value(source.public_send(name), format)
        end
      end
    end

    def custom_generation_options
      {
        serializer: self,
        serialization_options: @serialization_options
      }
    end

    def meta_hash(source)
      meta = source.meta(custom_generation_options)
      (meta.is_a?(Hash) && meta) || {}
    end

    def links_hash(source)
      links = custom_links_hash(source)
      if !links.key?('self') && !source.class.exclude_link?(:self)
        links['self'] = link_builder.self_link(source)
      end
      links.compact
    end

    def custom_links_hash(source)
      custom_links = source.custom_links(custom_generation_options)
      (custom_links.is_a?(Hash) && custom_links) || {}
    end

    def top_level_source_key(source)
      case source
      when CachedResourceFragment then "#{source.resource_klass}_#{source.id}"
      when Resource then "#{source.class}_#{@id_formatter.format(source.id)}"
      else raise "Unknown source type #{source.inspect}"
      end
    end

    def self_referential_and_already_in_source(resource)
      resource && @top_level_sources.include?(top_level_source_key(resource))
    end

    def relationships_hash(source, fetchable_fields, include_directives = {})
      if source.is_a?(CachedResourceFragment)
        return cached_relationships_hash(source, include_directives)
      end

      include_directives[:include_related] ||= {}

      relationships = source.class._relationships.select{|k,v| fetchable_fields.include?(k) }
      field_set = supplying_relationship_fields(source.class) & relationships.keys

      relationships.each_with_object({}) do |(name, relationship), hash|
        ia = include_directives[:include_related][name]
        include_linkage = ia && ia[:include]
        include_linked_children = ia && !ia[:include_related].empty?

        if field_set.include?(name)
          ro = relationship_object(source, relationship, include_linkage)
          hash[format_key(name)] = ro unless ro.blank?
        end

        # If the object has been serialized once it will be in the related objects list,
        # but it's possible all children won't have been captured. So we must still go
        # through the relationships.
        if include_linkage || include_linked_children
          resources = if source.preloaded_fragments.has_key?(format_key(name))
            source.preloaded_fragments[format_key(name)].values
          else
            options = { filters: ia && ia[:include_filters] || {} }
            [source.public_send(name, options)].flatten(1).compact
          end
          resources.each do |resource|
            next if self_referential_and_already_in_source(resource)
            id = resource.id
            relationships_only = already_serialized?(relationship.type, id)
            if include_linkage && !relationships_only
              add_resource(resource, ia)
            elsif include_linked_children || relationships_only
              relationships_hash(resource, fetchable_fields, ia)
            end
          end
        end
      end
    end

    def cached_relationships_hash(source, include_directives)
      h = source.relationships || {}
      return h unless include_directives.has_key?(:include_related)

      relationships = source.resource_klass._relationships.select do |k,v|
        source.fetchable_fields.include?(k)
      end

      real_res = nil
      relationships.each do |rel_name, relationship|
        key = @key_formatter.format(rel_name)
        to_many = relationship.is_a? JSONAPI::Relationship::ToMany

        ia = include_directives[:include_related][rel_name]
        if ia
          if h.has_key?(key)
            h[key][:data] = to_many ? [] : nil
          end

          fragments = source.preloaded_fragments[key]
          if fragments.nil?
            # The resources we want were not preloaded, we'll have to bypass the cache.
            # This happens when including through belongs_to polymorphic relationships
            if real_res.nil?
              real_res = source.to_real_resource
            end
            relation_resources = [real_res.public_send(rel_name)].flatten(1).compact
            fragments = relation_resources.map{|r| [r.id, r]}.to_h
          end

          fragments.each do |id, f|
            add_resource(f, ia)

            if h.has_key?(key)
              # The hash already has everything we need except the :data field
              data = {
                type: format_key(f.is_a?(Resource) ? f.class._type : f.type),
                id: @id_formatter.format(id)
              }

              if to_many
                h[key][:data] << data
              else
                h[key][:data] = data
              end
            end
          end
        end
      end

      return h
    end

    def already_serialized?(type, id)
      type = format_key(type)
      id = @id_formatter.format(id)
      @included_objects.key?(type) && @included_objects[type].key?(id)
    end

    def self_link(source, relationship)
      link_builder.relationships_self_link(source, relationship)
    end

    def related_link(source, relationship)
      link_builder.relationships_related_link(source, relationship)
    end

    def default_relationship_links(source, relationship)
      links = {}
      links['self'] = self_link(source, relationship) unless relationship.exclude_link?(:self)
      links['related'] = related_link(source, relationship) unless relationship.exclude_link?(:related)
      links.compact
    end

    def to_one_linkage(source, relationship)
      linkage_id = foreign_key_value(source, relationship)
      linkage_type = format_key(relationship.type_for_source(source))
      return unless linkage_id.present? && linkage_type.present?

      {
        type: linkage_type,
        id: linkage_id,
      }
    end

    def to_many_linkage(source, relationship)
      linkage = []
      include_config = include_directives.include_config(relationship.name.to_sym) if include_directives
      include_filters = include_config[:include_filters] if include_config
      options = { filters: include_filters || {} }

      linkage_types_and_values = if source.preloaded_fragments.has_key?(format_key(relationship.name))
        source.preloaded_fragments[format_key(relationship.name)].map do |_, resource|
          [relationship.type, resource.id]
        end
      elsif relationship.polymorphic?
        assoc = source.public_send("records_for_#{relationship.name}", options)
        # Avoid hitting the database again for values already pre-loaded
        if assoc.respond_to?(:loaded?) and assoc.loaded?
          assoc.map do |obj|
            [obj.type.underscore.pluralize, obj.id]
          end
        else
          assoc = assoc.unscope(:includes) if assoc.is_a?(ActiveRecord::Relation)
          assoc.pluck(:type, :id).map do |type, id|
            [type.underscore.pluralize, id]
          end
        end
      else
        source.public_send(relationship.name, options).map do |value|
          [relationship.type, value.id]
        end
      end

      linkage_types_and_values.each do |type, value|
        if type && value
          linkage.append({type: format_key(type), id: @id_formatter.format(value)})
        end
      end
      linkage
    end

    def relationship_object_to_one(source, relationship, include_linkage)
      include_linkage = include_linkage | @always_include_to_one_linkage_data | relationship.always_include_linkage_data
      relationship_object_hash = {}

      links = default_relationship_links(source, relationship)

      relationship_object_hash['links'] = links unless links.blank?
      relationship_object_hash[:data] = to_one_linkage(source, relationship) if include_linkage
      relationship_object_hash
    end

    def relationship_object_to_many(source, relationship, include_linkage)
      include_linkage = include_linkage | relationship.always_include_linkage_data
      relationship_object_hash = {}

      links = default_relationship_links(source, relationship)
      relationship_object_hash['links'] = links unless links.blank?
      relationship_object_hash[:data] = to_many_linkage(source, relationship) if include_linkage
      relationship_object_hash
    end

    def relationship_object(source, relationship, include_linkage = false)
      if relationship.is_a?(JSONAPI::Relationship::ToOne)
        relationship_object_to_one(source, relationship, include_linkage)
      elsif relationship.is_a?(JSONAPI::Relationship::ToMany)
        relationship_object_to_many(source, relationship, include_linkage)
      end
    end

    # Extracts the foreign key value for a to_one relationship.
    def foreign_key_value(source, relationship)
      # If you have changed the key_name, don't even try to look at `"#{relationship.name}_id"`
      # just load the association and call the custom key_name
      foreign_key_type_changed = relationship.options[:foreign_key_type_changed] || false
      related_resource_id =
        if source.preloaded_fragments.has_key?(format_key(relationship.name))
          source.preloaded_fragments[format_key(relationship.name)].values.first.try(:id)
        elsif !foreign_key_type_changed && source.respond_to?("#{relationship.name}_id")
          # If you have direct access to the underlying id, you don't have to load the relationship
          # which can save quite a lot of time when loading a lot of data.
          # This does not apply to e.g. has_one :through relationships.
          source.public_send("#{relationship.name}_id")
        else
          source.public_send(relationship.name).try(:id)
        end
      return nil unless related_resource_id
      @id_formatter.format(related_resource_id)
    end

    def foreign_key_types_and_values(source, relationship)
      if relationship.is_a?(JSONAPI::Relationship::ToMany)
        if relationship.polymorphic?
          assoc = source._model.public_send(relationship.name)
          # Avoid hitting the database again for values already pre-loaded
          if assoc.respond_to?(:loaded?) and assoc.loaded?
            assoc.map do |obj|
              [obj.type.underscore.pluralize, @id_formatter.format(obj.id)]
            end
          else
            assoc.pluck(:type, :id).map do |type, id|
              [type.underscore.pluralize, @id_formatter.format(id)]
            end
          end
        else
          source.public_send(relationship.name).map do |value|
            [relationship.type, @id_formatter.format(value.id)]
          end
        end
      end
    end

    # Sets that an object should be included in the primary document of the response.
    def set_primary(type, id)
      type = format_key(type)
      @included_objects[type][id][:primary] = true
    end

    def add_resource(source, include_directives, primary = false)
      type = source.is_a?(JSONAPI::CachedResourceFragment) ? source.type : source.class._type
      id = source.id

      @included_objects[type] ||= {}
      existing = @included_objects[type][id]

      if existing.nil?
        obj_hash = object_hash(source, include_directives)
        @included_objects[type][id] = {
            primary: primary,
            object_hash: obj_hash,
            includes: Set.new(include_directives[:include_related].keys)
        }
      else
        include_related = Set.new(include_directives[:include_related].keys)
        unless existing[:includes].superset?(include_related)
          obj_hash = object_hash(source, include_directives)
          @included_objects[type][id][:object_hash].deep_merge!(obj_hash)
          @included_objects[type][id][:includes].add(include_related)
          @included_objects[type][id][:primary] = existing[:primary] | primary
        end
      end
    end

    def generate_link_builder(primary_resource_klass, options)
      LinkBuilder.new(
        base_url: options.fetch(:base_url, ''),
        primary_resource_klass: primary_resource_klass,
        route_formatter: options.fetch(:route_formatter, JSONAPI.configuration.route_formatter),
        url_helpers: options.fetch(:url_helpers, options[:controller]),
      )
    end
  end
end
