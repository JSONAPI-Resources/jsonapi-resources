# frozen_string_literal: true

module JSONAPI
  class CompiledJson
    def self.compile(h)
      new(JSON.generate(h), h)
    end

    def self.of(obj)
      # :nocov:
      case obj
      when NilClass then nil
      when CompiledJson then obj
      when String then CompiledJson.new(obj)
      when Hash then CompiledJson.compile(obj)
      else raise "Can't figure out how to turn #{obj.inspect} into CompiledJson"
      end
      # :nocov:
    end

    def initialize(json, h = nil)
      @json = json
      @h = h
    end

    def to_json(*_args)
      @json
    end

    def to_s
      @json
    end

    # :nocov:
    def to_h
      @h ||= JSON.parse(@json)
    end
    # :nocov:

    def [](key)
      # :nocov:
      to_h[key]
      # :nocov:
    end

    undef_method :as_json
  end
end
