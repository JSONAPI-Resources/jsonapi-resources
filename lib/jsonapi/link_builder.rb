# frozen_string_literal: true

module JSONAPI
  class LinkBuilder
    attr_reader :base_url,
                :primary_resource_klass,
                :route_formatter,
                :engine,
                :engine_mount_point,
                :url_helpers

    @@url_helper_methods = {}

    def initialize(config = {})
      @base_url = config[:base_url]
      @primary_resource_klass = config[:primary_resource_klass]
      @route_formatter = config[:route_formatter]
      @engine = build_engine
      @engine_mount_point = @engine ? @engine.routes.find_script_name({}) : ""

      # url_helpers may be either a controller which has the route helper methods, or the application router's
      # url helpers module, `Rails.application.routes.url_helpers`. Because the method no longer behaves as a
      # singleton, and it's expensive to generate the module, the controller is preferred.
      @url_helpers = config[:url_helpers]
    end

    def engine?
      !!@engine
    end

    def primary_resources_url
      if @primary_resource_klass._routed
        primary_resources_path = resources_path(primary_resource_klass)
        @primary_resources_url_cached ||= "#{ base_url }#{ engine_mount_point }#{ primary_resources_path }"
      else
        if JSONAPI.configuration.warn_on_missing_routes && !@primary_resource_klass._warned_missing_route
          warn "primary_resources_url for #{@primary_resource_klass.name} could not be generated"
          @primary_resource_klass._warned_missing_route = true
        end
        nil
      end
    end

    def query_link(query_params)
      url = primary_resources_url
      return url if url.nil?
      "#{ url }?#{ query_params.to_query }"
    end

    def relationships_related_link(source, relationship, query_params = {})
      if relationship._routed
        url = +"#{ self_link(source) }/#{ route_for_relationship(relationship) }"
        url << "?#{ query_params.to_query }" if query_params.present?
        url
      else
        if JSONAPI.configuration.warn_on_missing_routes && !relationship._warned_missing_route
          warn "related_link for #{relationship.display_name} could not be generated"
          relationship._warned_missing_route = true
        end
        nil
      end
    end

    def relationships_self_link(source, relationship)
      if relationship._routed
        "#{ self_link(source) }/relationships/#{ route_for_relationship(relationship) }"
      else
        if JSONAPI.configuration.warn_on_missing_routes && !relationship._warned_missing_route
          warn "self_link for #{relationship.display_name} could not be generated"
          relationship._warned_missing_route = true
        end
        nil
      end
    end

    def self_link(source)
      if source.class._routed
        resource_url(source)
      else
        if JSONAPI.configuration.warn_on_missing_routes && !source.class._warned_missing_route
          warn "self_link for #{source.class.name} could not be generated"
          source.class._warned_missing_route = true
        end
        nil
      end
    end

    private

    def build_engine
      scopes = module_scopes_from_class(primary_resource_klass)

      begin
        unless scopes.empty?
          "#{ scopes.first.to_s.classify }::Engine".safe_constantize
        end

          # :nocov:
      rescue LoadError => _e
        nil
        # :nocov:
      end
    end

    def format_route(route)
      route_formatter.format(route)
    end

    def formatted_module_path_from_class(klass)
      scopes = if @engine
                 module_scopes_from_class(klass)[1..-1]
               else
                 module_scopes_from_class(klass)
               end

      unless scopes.empty?
        "/#{ scopes.map {|scope| format_route(scope.to_s.underscore)}.compact.join('/') }/"
      else
        "/"
      end
    end

    def module_scopes_from_class(klass)
      klass.name.to_s.split("::")[0...-1]
    end

    def resources_path(source_klass)
      @_resources_path ||= {}
      @_resources_path[source_klass] ||= formatted_module_path_from_class(source_klass) + format_route(source_klass._type.to_s)
    end

    def resource_url(source)
      if source.class.singleton?
        "#{ base_url }#{ engine_mount_point }#{ resources_path(source.class) }"
      else
        "#{ base_url }#{ engine_mount_point }#{resources_path(source.class)}/#{source.id}"
      end
    end

    def route_for_relationship(relationship)
      format_route(relationship.name)
    end
  end
end
