module Jsonapi
  class ScaffoldGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('templates', __dir__)

    def copy_application_record_file
      if namespace_path.present?
        @application_record_class = application_record_class
        path                      = namespaced_file_path(models_path, 'application_record.rb')
        template 'application_record.erb', path
      end
    end

    def copy_model_file
      @application_record_class = application_record_class
      @class_name               = full_namespace_class(file_name.camelize)
      path                      = namespaced_file_path(models_path, file_name + '.rb')
      template 'model.erb', path
    end

    def copy_application_resource_file
      @application_resource_class = application_resource_class
      path                        = namespaced_file_path(resources_path, 'application_resource.rb')
      template 'application_resource.erb', path
    end

    def copy_resource_file
      @application_resource_class = application_resource_class
      @class_name                 = full_namespace_class(file_name.camelize + 'Resource')
      path                        = namespaced_file_path(resources_path, file_name + '_resource.rb')
      template 'resource.erb', path
    end

    def copy_application_controller_file
      path = namespaced_file_path(controllers_path, 'application_controller.rb')
      @application_controller_class = application_controller_class

      if namespace_path.present?
        template 'application_controller.erb', path
      end

      inject_into_class(path, 'ApplicationController', 'include JSONAPI::ActsAsResourceController')
    end

    def copy_controller_file
      @application_controller_class = application_controller_class
      @class_name                   = full_namespace_class(file_name.camelize.pluralize + 'Controller')
      path                          = namespaced_file_path(controllers_path, file_name.pluralize + '_controller.rb')
      template 'controller.erb', path
    end

    def copy_route_file
      dynamic_routes_method = <<~ROUTE
        def draw_resource_route(route_name)
          instance_eval(File.read(Rails.root.join("config/routes/\#{route_name}.rb")))
        end\n
      ROUTE

      prepend_to_file 'config/routes.rb', dynamic_routes_method

      @route_content = recursive_routes(class_path.dup)

      route "draw_resource_route '#{file_path.pluralize}'"

      template "route.erb", namespaced_file_path('config/routes/', file_name.pluralize + '.rb')
    end

    private

    def models_path
      'app/models/'
    end

    def resources_path
      'app/resources/'
    end

    def controllers_path
      'app/controllers/'
    end

    def namespace_path
      class_path.map { |cp| cp + '/' }.join
    end

    def namespaced_file_path(prefix, file)
      prefix + namespace_path + file
    end

    def namespace_class
      class_path.map(&:camelize).map { |cp| cp + '::' }.join
    end

    def full_namespace_class(class_suffix)
      namespace_class + class_suffix
    end

    def application_record_class
      full_namespace_class('ApplicationRecord')
    end

    def application_resource_class
      full_namespace_class('ApplicationResource')
    end

    def application_controller_class
      full_namespace_class('ApplicationController')
    end

    def recursive_routes(path_elements, tab_count = 1)
      if path_elements.count == 0
        "jsonapi_resources :#{plural_name}"
      else
        namespace  = path_elements.shift
        start_tabs = "\t" * tab_count
        end_tabs   = "\t" * (tab_count - 1)
        "namespace :#{namespace} do\n#{start_tabs}#{recursive_routes(path_elements, tab_count + 1)}\n#{end_tabs}end"
      end
    end
  end
end
