# frozen_string_literal: true

require 'jsonapi/formatter'
require 'jsonapi/processor'
require 'concurrent'

module JSONAPI
  class Configuration
    attr_reader :json_key_format,
                :resource_key_type,
                :route_format,
                :raise_if_parameters_not_allowed,
                :warn_on_route_setup_issues,
                :warn_on_missing_routes,
                :warn_on_performance_issues,
                :default_allow_include_to_one,
                :default_allow_include_to_many,
                :allow_sort,
                :allow_filter,
                :default_paginator,
                :default_page_size,
                :maximum_page_size,
                :default_processor_klass_name,
                :use_text_errors,
                :top_level_links_include_pagination,
                :top_level_meta_include_record_count,
                :top_level_meta_record_count_key,
                :top_level_meta_include_page_count,
                :top_level_meta_page_count_key,
                :include_backtraces_in_errors,
                :include_application_backtraces_in_errors,
                :exception_class_allowlist,
                :allow_all_exceptions,
                :always_include_to_one_linkage_data,
                :always_include_to_many_linkage_data,
                :cache_formatters,
                :resource_cache,
                :default_caching,
                :default_resource_cache_field,
                :resource_cache_digest_function,
                :resource_cache_usage_report_function,
                :default_exclude_links,
                :use_related_resource_records_for_joins

    def initialize
      #:underscored_key, :camelized_key, :dasherized_key, or custom
      self.json_key_format = :dasherized_key

      #:underscored_route, :camelized_route, :dasherized_route, or custom
      self.route_format = :dasherized_route

      #:integer, :uuid, :string, or custom (provide a proc)
      self.resource_key_type = :integer

      # optional request features
      self.default_allow_include_to_one = true
      self.default_allow_include_to_many = true
      self.allow_sort = true
      self.allow_filter = true

      self.raise_if_parameters_not_allowed = true

      self.warn_on_route_setup_issues = true
      self.warn_on_missing_routes = true
      self.warn_on_performance_issues = true

      # :none, :offset, :paged, or a custom paginator name
      self.default_paginator = :none

      # Output pagination links at top level
      self.top_level_links_include_pagination = true

      self.default_page_size = 10
      self.maximum_page_size = 20

      # Metadata
      # Output record count in top level meta for find operation
      self.top_level_meta_include_record_count = false
      self.top_level_meta_record_count_key = :record_count

      self.top_level_meta_include_page_count = false
      self.top_level_meta_page_count_key = :page_count

      self.use_text_errors = false

      # Whether or not to include exception backtraces in JSONAPI error
      # responses.  Defaults to `false` in anything other than development or test.
      self.include_backtraces_in_errors = (Rails.env.development? || Rails.env.test?)

      # Whether or not to include exception application backtraces in JSONAPI error
      # responses.  Defaults to `false` in anything other than development or test.
      self.include_application_backtraces_in_errors = (Rails.env.development? || Rails.env.test?)

      # List of classes that should not be rescued by the operations processor.
      self.exception_class_allowlist = []

      # If enabled, will override configuration option `exception_class_allowlist`
      # and allow all exceptions.
      self.allow_all_exceptions = false

      # Resource Linkage
      # Controls the serialization of resource linkage for non compound documents
      self.always_include_to_one_linkage_data = false
      self.always_include_to_many_linkage_data = false

      # The default Operation Processor to use if one is not defined specifically
      # for a Resource.
      self.default_processor_klass_name = 'JSONAPI::Processor'

      # Formatter Caching
      # Set to false to disable caching of string operations on keys and links.
      self.cache_formatters = true

      # Resource cache
      # An ActiveSupport::Cache::Store or similar, used by Resources with caching enabled.
      self.resource_cache = nil

      # Cache resources by default
      self.default_caching = false

      # Default resource cache field
      self.default_resource_cache_field = :updated_at

      # Resource cache digest function
      self.resource_cache_digest_function = Digest::SHA2.new.method(:base64digest)

      # Resource cache usage reporting
      self.resource_cache_usage_report_function = nil

      # Global configuration for links exclusion
      self.default_exclude_links = :none

      # Use a related resource's `records` when performing joins.
      self.use_related_resource_records_for_joins = true
    end

    def cache_formatters=(bool)
      @cache_formatters = bool
      if bool
        @key_formatter_tlv = Concurrent::ThreadLocalVar.new
        @route_formatter_tlv = Concurrent::ThreadLocalVar.new
      else
        @key_formatter_tlv = nil
        @route_formatter_tlv = nil
      end
    end

    def json_key_format=(format)
      @json_key_format = format
      if defined?(@cache_formatters)
        @key_formatter_tlv = Concurrent::ThreadLocalVar.new
      end
    end

    def route_format=(format)
      @route_format = format
      if defined?(@cache_formatters)
        @route_formatter_tlv = Concurrent::ThreadLocalVar.new
      end
    end

    def key_formatter
      if self.cache_formatters
        formatter = @key_formatter_tlv.value
        return formatter if formatter
      end

      formatter = JSONAPI::Formatter.formatter_for(self.json_key_format)

      if self.cache_formatters
        formatter = @key_formatter_tlv.value = formatter.cached
      end

      return formatter
    end

    def resource_key_type=(key_type)
      @resource_key_type = key_type
    end

    def route_formatter
      if self.cache_formatters
        formatter = @route_formatter_tlv.value
        return formatter if formatter
      end

      formatter = JSONAPI::Formatter.formatter_for(self.route_format)

      if self.cache_formatters
        formatter = @route_formatter_tlv.value = formatter.cached
      end

      return formatter
    end

    def exception_class_allowed?(e)
      @allow_all_exceptions ||
        @exception_class_allowlist.flatten.any? { |k| e.class.ancestors.map(&:to_s).include?(k.to_s) }
    end

    def default_processor_klass
      @default_processor_klass ||= default_processor_klass_name.safe_constantize
    end

    def default_processor_klass_name=(default_processor_klass_name)
      @default_processor_klass = nil
      @default_processor_klass_name = default_processor_klass_name
    end

    attr_writer :allow_sort, :allow_filter, :default_allow_include_to_one, :default_allow_include_to_many

    attr_writer :default_paginator

    attr_writer :default_page_size

    attr_writer :maximum_page_size

    attr_writer :use_text_errors

    attr_writer :top_level_links_include_pagination

    attr_writer :top_level_meta_include_record_count

    attr_writer :top_level_meta_record_count_key

    attr_writer :top_level_meta_include_page_count

    attr_writer :top_level_meta_page_count_key

    attr_writer :include_backtraces_in_errors

    attr_writer :include_application_backtraces_in_errors

    attr_writer :exception_class_allowlist

    attr_writer :allow_all_exceptions

    attr_writer :always_include_to_one_linkage_data

    attr_writer :always_include_to_many_linkage_data

    attr_writer :raise_if_parameters_not_allowed

    attr_writer :warn_on_route_setup_issues

    attr_writer :warn_on_missing_routes

    attr_writer :warn_on_performance_issues

    attr_writer :resource_cache

    attr_writer :default_caching

    attr_writer :default_resource_cache_field

    attr_writer :resource_cache_digest_function

    attr_writer :resource_cache_usage_report_function

    attr_writer :default_exclude_links

    attr_writer :use_related_resource_records_for_joins
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end
  end

  def self.configure
    yield(configuration)
  end
end
