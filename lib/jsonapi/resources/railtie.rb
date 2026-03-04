# frozen_string_literal: true

module JSONAPI
  module Resources
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'tasks/check_upgrade.rake'
      end

      # https://guides.rubyonrails.org/v6.0/engines.html#available-hooks
      ActiveSupport.on_load(:action_dispatch_integration_test) do
        # Make response.parsed_body work
        ::ActionDispatch::IntegrationTest.register_encoder :api_json,
          param_encoder: ->(params) {
            params
          },
          response_parser: ->(body) {
            ::JSONAPI::MimeTypes.parser.call(body)
          }
      end

      config.before_initialize do
        if !Rails.application.config.eager_load && ::JSONAPI::configuration.warn_on_eager_loading_disabled
          warn 'WARNING: jsonapi-resources may not load polymorphic types when Rails `eager_load` is disabled. ' \
                 'Polymorphic types may be set per relationship . This warning may be disable in the configuration ' \
                 'by setting `warn_on_eager_loading_disabled` to false.'
        end
      end
      config.to_prepare do
        ::JSONAPI::Resource._clear_resource_type_to_klass_cache
        ::JSONAPI::Resource._clear_model_to_resource_type_cache
      end
    end
  end
end
