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

          if options[:except]
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create unless options[:except].include?(:create) || options[:except].include?('create')
            options[:except] << :update unless options[:except].include?(:update) || options[:except].include?('update')
            options[:except] << :destroy unless options[:except].include?(:destroy) || options[:except].include?('destroy')
          end

          resource @resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_resource] = @resource_type

              if block_given?
                yield
              else
                jsonapi_relationships
              end
            else
              # Rails 5+
              # Rails 8.1 changed SingletonResource.new to accept only 3 arguments (removed options)
              resource_arg = if Rails::VERSION::MAJOR >= 8 && Rails::VERSION::MINOR >= 1
                SingletonResource.new(@resource_type, api_only?, @scope[:shallow])
              else
                SingletonResource.new(@resource_type, api_only?, @scope[:shallow], options)
              end

              jsonapi_resource_scope(resource_arg, @resource_type) do
                if block_given?
                  yield
                else
                  jsonapi_relationships
                end
              end
            end
            # :nocov:
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

          if options[:except]
            options[:except] = Array(options[:except])
            options[:except] << :new unless options[:except].include?(:new) || options[:except].include?('new')
            options[:except] << :edit unless options[:except].include?(:edit) || options[:except].include?('edit')
          else
            options[:except] = [:new, :edit]
          end

          if res._immutable
            options[:except] << :create unless options[:except].include?(:create) || options[:except].include?('create')
            options[:except] << :update unless options[:except].include?(:update) || options[:except].include?('update')
            options[:except] << :destroy unless options[:except].include?(:destroy) || options[:except].include?('destroy')
          end

          resources @resource_type, options do
            # :nocov:
            if @scope.respond_to? :[]=
              # Rails 4
              @scope[:jsonapi_resource] = @resource_type
              if block_given?
                yield
              else
                jsonapi_relationships
              end
            else
              # Rails 5+
              # Rails 8.1 changed Resource.new to accept only 3 arguments (removed options)
              resource_arg = if Rails::VERSION::MAJOR >= 8 && Rails::VERSION::MINOR >= 1
                Resource.new(@resource_type, api_only?, @scope[:shallow])
              else
                Resource.new(@resource_type, api_only?, @scope[:shallow], options)
              end

              jsonapi_resource_scope(resource_arg, @resource_type) do
                if block_given?
                  yield
                else
                  jsonapi_relationships
                end
              end
            end
            # :nocov:
          end
        end

        def links_methods(options)
          default_methods = [:show, :create, :destroy, :update]
          if only = options[:only]
            Array(only).map(&:to_sym)
          elsif except = options[:except]
            default_methods - Array(except)
          else
            default_methods
          end
        end

        def jsonapi_link(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                  action: 'show_relationship', relationship: link_type.to_s, via: [:get],
                  as: "relationships/#{link_type}"
          end

          if res.mutable?
            if methods.include?(:update)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                    action: 'update_relationship', relationship: link_type.to_s, via: [:put, :patch]
            end

            if methods.include?(:destroy)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                    action: 'destroy_relationship', relationship: link_type.to_s, via: [:delete]
            end
          end
        end

        def jsonapi_links(*links)
          link_type = links.first
          formatted_relationship_name = format_route(link_type)
          options = links.extract_options!.dup

          res = JSONAPI::Resource.resource_klass_for(resource_type_with_module_prefix)
          options[:controller] ||= res._type.to_s

          methods = links_methods(options)

          if methods.include?(:show)
            match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                  action: 'show_relationship', relationship: link_type.to_s, via: [:get],
                  as: "relationships/#{link_type}"
          end

          if res.mutable?
            if methods.include?(:create)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                    action: 'create_relationship', relationship: link_type.to_s, via: [:post]
            end

            if methods.include?(:update)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                    action: 'update_relationship', relationship: link_type.to_s, via: [:put, :patch]
            end

            if methods.include?(:destroy)
              match "relationships/#{formatted_relationship_name}", controller: options[:controller],
                    action: 'destroy_relationship', relationship: link_type.to_s, via: [:delete]
            end
          end
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

        protected
        # :nocov:
        def jsonapi_resource_scope(resource, resource_type) #:nodoc:
          @scope = @scope.new(scope_level_resource: resource, jsonapi_resource: resource_type)

          controller(resource.resource_scope) { yield }
        ensure
          @scope = @scope.parent
        end
        # :nocov:

        private

        def resource_type_with_module_prefix(resource = nil)
          resource_name = resource || @scope[:jsonapi_resource]
          [@scope[:module], resource_name].compact.collect(&:to_s).join('/')
        end
      end
    end
  end
end
