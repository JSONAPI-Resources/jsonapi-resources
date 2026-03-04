# frozen_string_literal: true

module JSONAPI
  class ControllerGenerator < ::Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    def create_resource
      template_file = File.join(
        'app/controllers',
        class_path,
        "#{file_name.pluralize}_controller.rb"
      )
      template 'jsonapi_controller.rb', template_file
    end
  end
end
