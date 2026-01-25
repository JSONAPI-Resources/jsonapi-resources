# frozen_string_literal: true

module JSONAPI
  class CachedResponseFragment
    Lookup = Struct.new(:resource_klass, :serializer_config_key, :context, :context_key, :cache_ids) do
      def type
        resource_klass._type
      end

      def keys
        cache_ids.map do |(id, cache_key)|
          [type, id, cache_key, serializer_config_key, context_key]
        end
      end
    end

    Write = Struct.new(:resource_klass, :resource, :serializer, :serializer_config_key, :context, :context_key,
                       :relationship_data) do
      def to_key_value
        (id, cache_key) = resource.cache_id

        json = serializer.object_hash(resource, relationship_data)

        cr = CachedResponseFragment.new(
          resource_klass,
          id,
          json['type'],
          context,
          resource.fetchable_fields,
          json['relationships'],
          json['links'],
          json['attributes'],
          json['meta']
        )

        key = [resource_klass._type, id, cache_key, serializer_config_key, context_key]

        [key, cr]
      end
    end

    attr_reader :resource_klass, :id, :type, :context, :fetchable_fields, :relationships,
                :links_json, :attributes_json, :meta_json

    def initialize(resource_klass, id, type, context, fetchable_fields, relationships,
                   links_json, attributes_json, meta_json)
      @resource_klass = resource_klass
      @id = id
      @type = type
      @context = context
      @fetchable_fields = Set.new(fetchable_fields)

      # Relationships left uncompiled because we'll often want to insert included ids on retrieval
      # Remove the data since that should not be cached
      @relationships = relationships&.transform_values { |v| v.delete_if { |k, _v| k == 'data' } }
      @links_json = CompiledJson.of(links_json)
      @attributes_json = CompiledJson.of(attributes_json)
      @meta_json = CompiledJson.of(meta_json)
    end

    def to_cache_value
      {
        id: id,
        type: type,
        fetchable: fetchable_fields,
        rels: relationships,
        links: links_json.try(:to_s),
        attrs: attributes_json.try(:to_s),
        meta: meta_json.try(:to_s)
      }
    end

    # @param [Lookup[]] lookups
    # @return [Hash<Class<Resource>, Hash<ID, CachedResourceFragment>>]
    def self.lookup(lookups, context)
      type_to_klass = lookups.map { |l| [l.type, l.resource_klass] }.to_h

      keys = lookups.map(&:keys).flatten(1)

      hits = JSONAPI.configuration.resource_cache.read_multi(*keys).reject { |_, v| v.nil? }

      return keys.inject({}) do |hash, key|
        (type, id, _, _) = key
        resource_klass = type_to_klass[type]
        hash[resource_klass] ||= {}

        if hits.key?(key)
          hash[resource_klass][id] = self.from_cache_value(resource_klass, context, hits[key])
        else
          hash[resource_klass][id] = nil
        end

        hash
      end
    end

    # @param [Write[]] lookups
    def self.write(writes)
      key_values = writes.map(&:to_key_value)

      to_write = key_values.map { |(k, v)| [k, v.to_cache_value] }.to_h

      if JSONAPI.configuration.resource_cache.respond_to? :write_multi
        JSONAPI.configuration.resource_cache.write_multi(to_write)
      else
        to_write.each do |key, value|
          JSONAPI.configuration.resource_cache.write(key, value)
        end
      end
    end

    def self.from_cache_value(resource_klass, context, h)
      new(
        resource_klass,
        h.fetch(:id),
        h.fetch(:type),
        context,
        h.fetch(:fetchable),
        h.fetch(:rels, nil),
        h.fetch(:links, nil),
        h.fetch(:attrs, nil),
        h.fetch(:meta, nil)
      )
    end
  end
end
