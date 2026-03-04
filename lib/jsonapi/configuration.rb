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
                :warn_on_eager_loading_disabled,
                :warn_on_missing_relationships,
                :raise_on_missing_relationships,
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
                :allow_transactions,
                :include_backtraces_in_errors,
                :include_application_backtraces_in_errors,
                :exception_class_allowlist,
                :allow_all_exceptions,
                :always_include_to_one_linkage_data,
                :always_include_to_many_linkage_data,
                :cache_formatters,
                :use_relationship_reflection,
                :resource_cache,
                :default_caching,
                :default_resource_cache_field,
                :resource_cache_digest_function,
                :resource_cache_usage_report_function,
                :default_exclude_links,
                :default_resource_retrieval_strategy,
                :use_related_resource_records_for_joins,
                :related_identities_set

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
      self.warn_on_eager_loading_disabled = true
      self.warn_on_missing_relationships = true
      # If this is set to true an error will be raised if a resource is found to be missing a relationship
      # If this is set to false a warning will be logged (see warn_on_missing_relationships) and related resouces for
      # this relationship will not be included in the response.
      self.raise_on_missing_relationships = false

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
      self.include_backtraces_in_errors = (::Rails.env.development? || ::Rails.env.test?)

      # Whether or not to include exception application backtraces in JSONAPI error
      # responses.  Defaults to `false` in anything other than development or test.
      self.include_application_backtraces_in_errors = (::Rails.env.development? || ::Rails.env.test?)

      # List of classes that should not be rescued by the operations processor.
      # For example, if you use Pundit for authorization, you might
      # raise a Pundit::NotAuthorizedError at some point during operations
      # processing. If you want to use Rails' `rescue_from` macro to
      # catch this error and render a 403 status code, you should add
      # the `Pundit::NotAuthorizedError` to the `exception_class_allowlist`.
      self.exception_class_allowlist = []

      # If enabled, will override configuration option `exception_class_allowlist`
      # and allow all exceptions.
      self.allow_all_exceptions = false

      # Resource Linkage
      # Controls the serialization of resource linkage for non compound documents
      # NOTE: always_include_to_many_linkage_data is not currently implemented
      self.always_include_to_one_linkage_data = false
      self.always_include_to_many_linkage_data = false

      # The default Operation Processor to use if one is not defined specifically
      # for a Resource.
      self.default_processor_klass_name = 'JSONAPI::Processor'

      # Allows transactions for creating and updating records
      # Set this to false if your backend does not support transactions (e.g. Mongodb)
      self.allow_transactions = true

      # Formatter Caching
      # Set to false to disable caching of string operations on keys and links.
      # Note that unlike the resource cache, formatter caching is always done
      # internally in-memory and per-thread; no ActiveSupport::Cache is used.
      self.cache_formatters = true

      # Relationship reflection invokes the related resource when updates
      # are made to a has_many relationship. By default relationship_reflection
      # is turned off because it imposes a small performance penalty.
      self.use_relationship_reflection = false

      # Resource cache
      # An ActiveSupport::Cache::Store or similar, used by Resources with caching enabled.
      # Set to `nil` (the default) to disable caching, or to `Rails.cache` to use the
      # Rails cache store.
      self.resource_cache = nil

      # Cache resources by default
      # Cache resources by default. Individual resources can be excluded from caching by calling:
      # `caching false`
      self.default_caching = false

      # Default resource cache field
      # On Resources with caching enabled, this field will be used to check for out-of-date
      # cache entries, unless overridden on a specific Resource. Defaults to "updated_at".
      self.default_resource_cache_field = :updated_at

      # Resource cache digest function
      # Provide a callable that returns a unique value for string inputs with
      # low chance of collision. The default is SHA256 base64.
      self.resource_cache_digest_function = Digest::SHA2.new.method(:base64digest)

      # Resource cache usage reporting
      # Optionally provide a callable which JSONAPI will call with information about cache
      # performance. Should accept three arguments: resource name, hits count, misses count.
      self.resource_cache_usage_report_function = nil

      # Global configuration for links exclusion
      # Controls whether to generate links like `self`, `related` with all the resources
      # and relationships. Accepts either `:default`, `:none`, or array containing the
      # specific default links to exclude, which may be `:self` and `:related`.
      self.default_exclude_links = :none

      # Global configuration for resource retrieval strategy used by the Resource class.
      # Selecting a default_resource_retrieval_strategy will affect all resources that derive from
      # Resource. The default value is 'JSONAPI::ActiveRelationRetrieval'.
      #
      # To use multiple retrieval strategies in an app set this to :none and set a custom retrieval strategy
      # per resource (or base resource) using the class method `load_resource_retrieval_strategy`.
      #
      # Available strategies:
      # 'JSONAPI::ActiveRelationRetrieval'
      # 'JSONAPI::ActiveRelationRetrievalV09'
      # 'JSONAPI::ActiveRelationRetrievalV10'
      # :none
      # :self
      self.default_resource_retrieval_strategy = 'JSONAPI::ActiveRelationRetrieval'

      # For 'JSONAPI::ActiveRelationRetrievalV10': use a related resource's `records` when performing joins.
      # This setting allows included resources to account for permission scopes. It can be overridden explicitly per
      # relationship. Furthermore, specifying a `relation_name` on a relationship will cause this setting to be ignored.
      self.use_related_resource_records_for_joins = true

      # Collect the include keys into a Set or a SortedSet. SortedSet carries a small performance cost in the rails app
      # but produces consistent and more human navigable result sets.
      # To use SortedSet be sure to add `sorted_set` to your Gemfile and the following two lines to your JR initializer:
      # require 'sorted_set'
      # config.related_identities_set = SortedSet
      self.related_identities_set = Set
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

    def deprecate(msg)
      if defined?(ActiveSupport.deprecator)
        ActiveSupport.deprecator.warn(msg)
      else
        ActiveSupport::Deprecation.warn(msg)
      end
    end

    def default_processor_klass=(default_processor_klass)
      deprecate('`default_processor_klass` has been replaced by `default_processor_klass_name`.')
      @default_processor_klass = default_processor_klass
    end

    def default_processor_klass
      @default_processor_klass ||= default_processor_klass_name.safe_constantize
    end

    def default_processor_klass_name=(default_processor_klass_name)
      @default_processor_klass = nil
      @default_processor_klass_name = default_processor_klass_name
    end

    def allow_include=(allow_include)
      deprecate('`allow_include` has been replaced by `default_allow_include_to_one` and `default_allow_include_to_many` options.')
      @default_allow_include_to_one = allow_include
      @default_allow_include_to_many = allow_include
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

    attr_writer :allow_transactions

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

    attr_writer :warn_on_eager_loading_disabled

    attr_writer :warn_on_missing_relationships

    attr_writer :raise_on_missing_relationships

    attr_writer :use_relationship_reflection

    attr_writer :resource_cache

    attr_writer :default_caching

    attr_writer :default_resource_cache_field

    attr_writer :resource_cache_digest_function

    attr_writer :resource_cache_usage_report_function

    attr_writer :default_exclude_links

    attr_writer :default_resource_retrieval_strategy

    attr_writer :use_related_resource_records_for_joins

    attr_writer :related_identities_set
  end

  class << self
    attr_accessor :configuration
  end

  @configuration ||= Configuration.new

  def self.configure
    yield(@configuration)
  end
end
