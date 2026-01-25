# frozen_string_literal: true

module JSONAPI
  class Formatter
    class << self
      def format(arg)
        arg.to_s
      end

      def unformat(arg)
        arg
      end

      def cached
        return FormatterWrapperCache.new(self)
      end

      def uncached
        return self
      end

      def formatter_for(format)
        "#{format.to_s.camelize}Formatter".safe_constantize
      end
    end
  end

  class KeyFormatter < Formatter
    class << self
      def format(key)
        super
      end

      def unformat(formatted_key)
        super
      end
    end
  end

  class RouteFormatter < Formatter
    class << self
      def format(route)
        super
      end

      def unformat(formatted_route)
        super
      end
    end
  end

  class ValueFormatter < Formatter
    class << self
      def format(raw_value)
        super(raw_value)
      end

      def unformat(value)
        super(value)
      end

      def value_formatter_for(type)
        "#{type.to_s.camelize}ValueFormatter".safe_constantize
      end
    end
  end

  # Warning: Not thread-safe. Wrap in ThreadLocalVar as needed.
  class FormatterWrapperCache
    attr_reader :formatter_klass

    def initialize(formatter_klass)
      @formatter_klass = formatter_klass
      @format_cache = NaiveCache.new { |arg| formatter_klass.format(arg) }
      @unformat_cache = NaiveCache.new { |arg| formatter_klass.unformat(arg) }
    end

    def format(arg)
      @format_cache.get(arg)
    end

    def unformat(arg)
      @unformat_cache.get(arg)
    end

    def cached
      self
    end

    def uncached
      return @formatter_klass
    end
  end
end

class UnderscoredKeyFormatter < JSONAPI::KeyFormatter
end

class CamelizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(key)
      super.camelize(:lower)
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DasherizedKeyFormatter < JSONAPI::KeyFormatter
  class << self
    def format(_key)
      super.underscore.dasherize
    end

    def unformat(formatted_key)
      formatted_key.to_s.underscore
    end
  end
end

class DefaultValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      case raw_value
      when Date, Time, DateTime, ActiveSupport::TimeWithZone, BigDecimal
        # Use the as_json methods added to various base classes by ActiveSupport
        return raw_value.as_json
      else
        return raw_value
      end
    end
  end
end

class IdValueFormatter < JSONAPI::ValueFormatter
  class << self
    def format(raw_value)
      return if raw_value.nil?

      raw_value.to_s
    end
  end
end

class UnderscoredRouteFormatter < JSONAPI::RouteFormatter
end

class CamelizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    def format(_route)
      super.camelize(:lower)
    end

    def unformat(formatted_route)
      formatted_route.to_s.underscore
    end
  end
end

class DasherizedRouteFormatter < JSONAPI::RouteFormatter
  class << self
    def format(_route)
      super.dasherize
    end

    def unformat(formatted_route)
      formatted_route.to_s.underscore
    end
  end
end
