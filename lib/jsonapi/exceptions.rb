# frozen_string_literal: true

module JSONAPI
  module Exceptions
    class Error < RuntimeError
      attr_reader :error_object_overrides

      def initialize(error_object_overrides = {})
        @error_object_overrides = error_object_overrides
      end

      def create_error_object(error_defaults)
        JSONAPI::Error.new(error_defaults.merge(error_object_overrides))
      end

      def errors
        # :nocov:
        raise NotImplementedError, "Subclass of Error must implement errors method"
        # :nocov:
      end
    end

    class Errors < Error
      def initialize(errors, error_object_overrides = {})
        @errors = errors

        @errors.each do |error|
          error.update_with_overrides(error_object_overrides)
        end

        super(error_object_overrides)
      end

      def errors
        @errors
      end
    end

    class InternalServerError < Error
      attr_accessor :exception

      def initialize(exception, error_object_overrides = {})
        @exception = exception
        super(error_object_overrides)
      end

      def errors
        if JSONAPI.configuration.include_backtraces_in_errors
          meta = Hash.new
          meta[:exception] = exception.message
          meta[:backtrace] = exception.backtrace
        end

        if JSONAPI.configuration.include_application_backtraces_in_errors
          meta ||= Hash.new
          meta[:exception] ||= exception.message
          meta[:application_backtrace] = exception.backtrace.select{|line| line =~ /#{::Rails.root}/}
        end

        [create_error_object(code: JSONAPI::INTERNAL_SERVER_ERROR,
                             status: :internal_server_error,
                             title: I18n.t('jsonapi-resources.exceptions.internal_server_error.title',
                                           default: 'Internal Server Error'),
                             detail: I18n.t('jsonapi-resources.exceptions.internal_server_error.detail',
                                            default: 'Internal Server Error'),
                             meta: meta)]
      end
    end

    class InvalidResource < Error
      attr_accessor :resource

      def initialize(resource, error_object_overrides = {})
        @resource = resource
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_RESOURCE,
                             status: :bad_request,
                             title: I18n.t('jsonapi-resources.exceptions.invalid_resource.title',
                                           default: 'Invalid resource'),
                             detail: I18n.t('jsonapi-resources.exceptions.invalid_resource.detail',
                                            default: "#{resource} is not a valid resource.", resource: resource))]
      end
    end

    class RecordNotFound < Error
      attr_accessor :id

      def initialize(id, error_object_overrides = {})
        @id = id
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::RECORD_NOT_FOUND,
                             status: :not_found,
                             title: I18n.translate('jsonapi-resources.exceptions.record_not_found.title',
                                                   default: 'Record not found'),
                             detail: I18n.translate('jsonapi-resources.exceptions.record_not_found.detail',
                                                    default: "The record identified by #{id} could not be found.", id: id))]
      end
    end

    class UnsupportedMediaTypeError < Error
      attr_accessor :media_type

      def initialize(media_type, error_object_overrides = {})
        @media_type = media_type
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::UNSUPPORTED_MEDIA_TYPE,
                             status: :unsupported_media_type,
                             title: I18n.translate('jsonapi-resources.exceptions.unsupported_media_type.title',
                                                   default: 'Unsupported media type'),
                             detail: I18n.translate('jsonapi-resources.exceptions.unsupported_media_type.detail',
                                                    default: "All requests that create or update must use the '#{JSONAPI::MEDIA_TYPE}' Content-Type. This request specified '#{media_type}'.",
                                                    needed_media_type: JSONAPI::MEDIA_TYPE,
                                                    media_type: media_type))]
      end
    end

    class NotAcceptableError < Error
      attr_accessor :media_type

      def initialize(media_type, error_object_overrides = {})
        @media_type = media_type
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::NOT_ACCEPTABLE,
                             status: :not_acceptable,
                             title: I18n.translate('jsonapi-resources.exceptions.not_acceptable.title',
                                                   default: 'Not acceptable'),
                             detail: I18n.translate('jsonapi-resources.exceptions.not_acceptable.detail',
                                                    default: "All requests must use the '#{JSONAPI::MEDIA_TYPE}' Accept without media type parameters. This request specified '#{media_type}'.",
                                                    needed_media_type: JSONAPI::MEDIA_TYPE,
                                                    media_type: media_type))]
      end
    end

    class BadRequest < Error
      def initialize(exception, error_object_overrides = {})
        @exception = exception
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::BAD_REQUEST,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.bad_request.title',
                                                   default: 'Bad Request'),
                             detail: I18n.translate('jsonapi-resources.exceptions.bad_request.detail',
                                                    default: @exception))]
      end
    end

    class InvalidRequestFormat < Error
      def errors
        [create_error_object(code: JSONAPI::BAD_REQUEST,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_request_format.title',
                                                   default: 'Bad Request'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_request_format.detail',
                                                    default: 'Request must be a hash'))]
      end
    end

    class ToManySetReplacementForbidden < Error
      def errors
        [create_error_object(code: JSONAPI::FORBIDDEN,
                             status: :forbidden,
                             title: I18n.translate('jsonapi-resources.exceptions.to_many_set_replacement_forbidden.title',
                                                   default: 'Complete replacement forbidden'),
                             detail: I18n.translate('jsonapi-resources.exceptions.to_many_set_replacement_forbidden.detail',
                                                    default: 'Complete replacement forbidden for this relationship'))]
      end
    end

    class InvalidFiltersSyntax < Error
      attr_accessor :filters

      def initialize(filters, error_object_overrides = {})
        @filters = filters
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_FILTERS_SYNTAX,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_filter_syntax.title',
                                                   default: 'Invalid filters syntax'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_filter_syntax.detail',
                                                    default: "#{filters} is not a valid syntax for filtering.",
                                                    filters: filters))]
      end
    end

    class FilterNotAllowed < Error
      attr_accessor :filter

      def initialize(filter, error_object_overrides = {})
        @filter = filter
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::FILTER_NOT_ALLOWED,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.filter_not_allowed.title',
                                                   default: 'Filter not allowed'),
                             detail: I18n.translate('jsonapi-resources.exceptions.filter_not_allowed.detail',
                                                    default: "#{filter} is not allowed.", filter: filter))]
      end
    end

    class InvalidFilterValue < Error
      attr_accessor :filter, :value

      def initialize(filter, value, error_object_overrides = {})
        @filter = filter
        @value = value
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_FILTER_VALUE,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_filter_value.title',
                                                   default: 'Invalid filter value'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_filter_value.detail',
                                                    default: "#{value} is not a valid value for #{filter}.",
                                                    value: value, filter: filter))]
      end
    end

    class InvalidFieldValue < Error
      attr_accessor :field, :value

      def initialize(field, value, error_object_overrides = {})
        @field = field
        @value = value
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_FIELD_VALUE,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_field_value.title',
                                                   default: 'Invalid field value'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_field_value.detail',
                                                    default: "#{value} is not a valid value for #{field}.",
                                                    value: value, field: field))]
      end
    end

    class InvalidFieldFormat < Error
      def errors
        [create_error_object(code: JSONAPI::INVALID_FIELD_FORMAT,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_field_format.title',
                                                   default: 'Invalid field format'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_field_format.detail',
                                                    default: 'Fields must specify a type.'))]
      end
    end

    class InvalidDataFormat < Error
      def errors
        [create_error_object(code: JSONAPI::INVALID_DATA_FORMAT,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_data_format.title',
                                                   default: 'Invalid data format'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_data_format.detail',
                                                    default: 'Data must be a hash.'))]
      end
    end

    class InvalidLinksObject < Error
      def errors
        [create_error_object(code: JSONAPI::INVALID_LINKS_OBJECT,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_links_object.title',
                                                   default: 'Invalid Links Object'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_links_object.detail',
                                                    default: 'Data is not a valid Links Object.'))]
      end
    end

    class TypeMismatch < Error
      attr_accessor :type

      def initialize(type, error_object_overrides = {})
        @type = type
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::TYPE_MISMATCH,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.type_mismatch.title',
                                                   default: 'Type Mismatch'),
                             detail: I18n.translate('jsonapi-resources.exceptions.type_mismatch.detail',
                                                    default: "#{type} is not a valid type for this operation.", type: type))]
      end
    end

    class InvalidField < Error
      attr_accessor :field, :type

      def initialize(type, field, error_object_overrides = {})
        @field = field
        @type = type
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_FIELD,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_field.title',
                                                   default: 'Invalid field'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_field.detail',
                                                    default: "#{field} is not a valid field for #{type}.",
                                                    field: field, type: type))]
      end
    end

    class InvalidRelationship < Error
      attr_accessor :relationship_name, :type

      def initialize(type, relationship_name, error_object_overrides = {})
        @relationship_name = relationship_name
        @type = type
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_RELATIONSHIP,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_relationship.title',
                                                   default: 'Invalid relationship'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_relationship.detail',
                                                    default: "#{relationship_name} is not a valid field for #{type}.",
                                                    relationship_name: relationship_name, type: type))]
      end
    end

    class InvalidInclude < Error
      attr_accessor :relationship, :resource

      def initialize(resource, relationship, error_object_overrides = {})
        @resource = resource
        @relationship = relationship
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_INCLUDE,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_include.title',
                                                   default: 'Invalid field'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_include.detail',
                                                    default: "#{relationship} is not a valid includable relationship of #{resource}",
                                                    relationship: relationship, resource: resource))]
      end
    end

    class InvalidSortCriteria < Error
      attr_accessor :sort_criteria, :resource

      def initialize(resource, sort_criteria, error_object_overrides = {})
        @resource = resource
        @sort_criteria = sort_criteria
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_SORT_CRITERIA,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_sort_criteria.title',
                                                   default: 'Invalid sort criteria'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_sort_criteria.detail',
                                                    default: "#{sort_criteria} is not a valid sort criteria for #{resource}",
                                                    sort_criteria: sort_criteria, resource: resource))]
      end
    end

    class ParameterNotAllowed < Error
      attr_accessor :param

      def initialize(param, error_object_overrides = {})
        @param = param
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::PARAM_NOT_ALLOWED,
                            status: :bad_request,
                            title: I18n.translate('jsonapi-resources.exceptions.parameter_not_allowed.title',
                                                  default: 'Param not allowed'),
                            detail: I18n.translate('jsonapi-resources.exceptions.parameters_not_allowed.detail',
                                                   default: "#{param} is not allowed.", param: param))]
      end
    end

    class ParameterMissing < Error
      attr_accessor :param

      def initialize(param, error_object_overrides = {})
        @param = param
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::PARAM_MISSING,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.parameter_missing.title',
                                                   default: 'Missing Parameter'),
                             detail: I18n.translate('jsonapi-resources.exceptions.parameter_missing.detail',
                                                    default: "The required parameter, #{param}, is missing.", param: param))]
      end
    end

    class KeyNotIncludedInURL < Error
      attr_accessor :key

      def initialize(key, error_object_overrides = {})
        @key = key
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::KEY_NOT_INCLUDED_IN_URL,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.key_not_included_in_url.title',
                                                   default: 'Key is not included in URL'),
                             detail: I18n.translate('jsonapi-resources.exceptions.key_not_included_in_url.detail',
                                                    default: "The URL does not support the key #{key}",
                                                    key: key))]
      end
    end

    class MissingKey < Error
      def errors
        [create_error_object(code: JSONAPI::KEY_ORDER_MISMATCH,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.missing_key.title',
                                                   default: 'A key is required'),
                             detail: I18n.translate('jsonapi-resources.exceptions.missing_key.detail',
                                                    default: 'The resource object does not contain a key.'))]
      end
    end

    class RecordLocked < Error
      attr_accessor :message

      def initialize(message, error_object_overrides = {})
        @message = message
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::LOCKED,
                             status: :locked,
                             title: I18n.translate('jsonapi-resources.exceptions.record_locked.title',
                                                   default: 'Locked resource'),
                             detail: "#{message}")]
      end
    end

    class ValidationErrors < Error
      attr_reader :error_messages, :error_metadata, :resource_relationships, :resource_class

      def initialize(resource, error_object_overrides = {})
        @error_messages = resource.model_error_messages
        @error_metadata = resource.validation_error_metadata
        @resource_class = resource.class
        @resource_relationships = resource.class._relationships.keys
        @key_formatter = JSONAPI.configuration.key_formatter
        super(error_object_overrides)
      end

      def format_key(key)
        @key_formatter.format(key)
      end

      def errors
        error_messages.flat_map do |attr_key, messages|
          messages.map { |message| json_api_error(attr_key, message) }
        end
      end

      private

      def json_api_error(attr_key, message)
        create_error_object(code: JSONAPI::VALIDATION_ERROR,
                            status: :unprocessable_entity,
                            title: message,
                            detail: detail(attr_key, message),
                            source: { pointer: pointer(attr_key) },
                            meta: metadata_for(attr_key, message))
      end

      def metadata_for(attr_key, message)
        return if error_metadata.nil?
        error_metadata[attr_key] ? error_metadata[attr_key][message] : nil
      end

      def detail(attr_key, message)
        general_error?(attr_key) ? message : "#{format_key(attr_key)} - #{message}"
      end

      def pointer(attr_or_relationship_name)
        return '/data' if general_error?(attr_or_relationship_name)
        formatted_attr_or_relationship_name = format_key(attr_or_relationship_name)
        if resource_relationships.include?(attr_or_relationship_name)
          "/data/relationships/#{formatted_attr_or_relationship_name}"
        else
          "/data/attributes/#{formatted_attr_or_relationship_name}"
        end
      end

      def general_error?(attr_key)
        attr_key.to_sym == :base && !resource_class._has_attribute?(attr_key)
      end
    end

    class SaveFailed < Error
      def errors
        [create_error_object(code: JSONAPI::SAVE_FAILED,
                             status: :unprocessable_entity,
                             title: I18n.translate('jsonapi-resources.exceptions.save_failed.title',
                                                   default: 'Save failed or was cancelled'),
                             detail: I18n.translate('jsonapi-resources.exceptions.save_failed.detail',
                                                    default: 'Save failed or was cancelled'))]
      end
    end

    class InvalidPageObject < Error
      def errors
        [create_error_object(code: JSONAPI::INVALID_PAGE_OBJECT,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_page_object.title',
                                                   default: 'Invalid Page Object'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_page_object.detail',
                                                    default: 'Invalid Page Object.'))]
      end
    end

    class PageParametersNotAllowed < Error
      attr_accessor :params

      def initialize(params, error_object_overrides = {})
        @params = params
        super(error_object_overrides)
      end

      def errors
        params.collect do |param|
          create_error_object(code: JSONAPI::PARAM_NOT_ALLOWED,
                              status: :bad_request,
                              title: I18n.translate('jsonapi-resources.exceptions.page_parameters_not_allowed.title',
                                                    default: 'Page parameter not allowed'),
                              detail: I18n.translate('jsonapi-resources.exceptions.page_parameters_not_allowed.detail',
                                                     default: "#{param} is not an allowed page parameter.",
                                                     param: param))
        end
      end
    end

    class InvalidPageValue < Error
      attr_accessor :page, :value

      def initialize(page, value, error_object_overrides = {})
        @page = page
        @value = value
        super(error_object_overrides)
      end

      def errors
        [create_error_object(code: JSONAPI::INVALID_PAGE_VALUE,
                             status: :bad_request,
                             title: I18n.translate('jsonapi-resources.exceptions.invalid_page_value.title',
                                                   default: 'Invalid page value'),
                             detail: I18n.translate('jsonapi-resources.exceptions.invalid_page_value.detail',
                                                    default: "#{value} is not a valid value for #{page} page parameter.",
                                                    value: value, page: page))]
      end
    end
  end
end
