# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Mapper
      Resource.class_eval do
        def unformat_route(route)
          JSONAPI.configuration.route_formatter.unformat(route.to_s)
        end

        def nested_param
          :"#{unformat_route(singular)}_#{param}"
        end
      end

      Resources.class_eval do
        def format_route(route)
          JSONAPI.configuration.route_formatter.format(route.to_s)
        end

        def jsonapi_resource(*resources, &_block)
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          res._routed = true

          unless res.singleton?
            warn "Singleton routes created for non singleton resource #{res}. Links may not be generated correctly."
          end

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)
          options[:path] = format_route(@resource_type)

          # Read-only: exclude all write actions
          options[:except] = [:new, :edit, :create, :update, :destroy]

          resource @resource_type, options do
            # Rails 8.1+ code path
            @jsonapi_resource_type = @resource_type
            if block_given?
              yield
            else
              jsonapi_relationships
            end
          end
        end

        def jsonapi_relationships(options = {})
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))
          res._relationships.each do |relationship_name, relationship|
            if relationship.is_a?(JSONAPI::Relationship::ToMany)
              jsonapi_links(relationship_name, options)
              jsonapi_related_resources(relationship_name, options)
            else
              jsonapi_link(relationship_name, options)
              jsonapi_related_resource(relationship_name, options)
            end
          end
        end

        def jsonapi_resources(*resources, &_block)
          @resource_type = resources.first
          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(@resource_type))

          res._routed = true

          if res.singleton?
            warn "Singleton resource #{res} should use `jsonapi_resource` instead."
          end

          options = resources.extract_options!.dup
          options[:controller] ||= @resource_type
          options.merge!(res.routing_resource_options)

          options[:param] = :id

          options[:path] = format_route(@resource_type)

          if res.resource_key_type == :uuid
            options[:constraints] ||= {}
            options[:constraints][:id] ||= /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/
          end

          # Read-only: exclude all write actions
          options[:except] = [:new, :edit, :create, :update, :destroy]

          resources @resource_type, options do
            # Rails 8.1+ code path
            @jsonapi_resource_type = @resource_type
            if block_given?
              yield
            else
              jsonapi_relationships
            end
          end
        end

        def jsonapi_link(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          # Read-only: only show relationship
          match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                action: 'show_relationship', relationship: link_type.to_s, via: [:get],
                                                                as: "relationships/#{link_type}"
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          # Read-only: only show relationship
          match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                                                                action: 'show_relationship', relationship: link_type.to_s, via: [:get],
                                                                as: "relationships/#{link_type}"
        end

        def jsonapi_related_resource(*relationship)
          source = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          relationship._routed = true

          formatted_relationship_name = format_route(relationship.name)

          if relationship.polymorphic?
            options[:controller] ||= relationship.class_name.underscore.pluralize
          else
            related_resource = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(relationship.class_name.underscore.pluralize))
            options[:controller] ||= related_resource._type.to_s
          end

          match formatted_relationship_name, controller: options[:controller],
                                             relationship: relationship.name, source: resource_type_with_module_prefix(source._type),
                                             action: 'show_related_resource', via: [:get],
                                             as: "related/#{relationship_name}"
        end

        def jsonapi_related_resources(*relationship)
          source = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options = relationship.extract_options!.dup

          relationship_name = relationship.first
          relationship = source._relationships[relationship_name]

          relationship._routed = true

          formatted_relationship_name = format_route(relationship.name)
          related_resource = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix(relationship.class_name.underscore))
          options[:controller] ||= related_resource._type.to_s

          match formatted_relationship_name,
                controller: options[:controller],
                relationship: relationship.name, source: resource_type_with_module_prefix(source._type),
                action: 'index_related_resources', via: [:get],
                as: "related/#{relationship_name}"
        end

        private

        def resource_type_with_module_prefix(resource = nil)
          resource_name = resource || @scope[:jsonapi_resource] || @jsonapi_resource_type
          [@scope[:module], resource_name].compact.collect(&:to_s).join('/')
        end
      end
    end
  end
end
