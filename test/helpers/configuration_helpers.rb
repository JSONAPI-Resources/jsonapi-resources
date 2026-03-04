module Helpers
  module ConfigurationHelpers
    def with_jsonapi_config_changes(&block)
      orig_config = JSONAPI.configuration.dup
      yield
    ensure
      $PostProcessorRaisesErrors = false
      $PostSerializerRaisesErrors = false
      JSONAPI.configuration = orig_config
    end

    def with_jsonapi_config(new_config_options)
      original_config = JSONAPI.configuration.dup # TODO should be a deep dup
      begin
        new_config_options.each do |k, v|
          JSONAPI.configuration.send(:"#{k}=", v)
        end
        return yield
      ensure
        JSONAPI.configuration = original_config
      end
    end

    def with_resource_caching(cache, classes = :all)
      results = {total: {hits: 0, misses: 0}}
      new_config_options = {
        resource_cache: cache,
        default_caching: true,
        resource_cache_usage_report_function: Proc.new do |name, hits, misses|
          [name.to_sym, :total].each do |key|
            results[key] ||= {hits: 0, misses: 0}
            results[key][:hits] += hits
            results[key][:misses] += misses
          end
        end
      }

      with_jsonapi_config(new_config_options) do
        if classes == :all or (classes.is_a?(Hash) && classes.keys == [:except])
          resource_classes = ObjectSpace.each_object(Class).select do |klass|
            if klass < JSONAPI::Resource
              # Not using Resource#_model_class to avoid tripping the warning early, which could
              # cause ResourceTest#test_nil_model_class to fail.
              model_class = klass._model_name.to_s.safe_constantize
              if model_class && model_class.respond_to?(:arel_table)
                next true
              end
            end
            next false
          end

          if classes.is_a?(Hash)
            classes.values.first.each do |excluded|
              deleted = resource_classes.delete(excluded)
              raise "Can't find #{excluded} among AR-based Resource classes" if deleted.nil?
            end
          end

          classes = resource_classes
        end

        begin
          yield
        end
      end

      return results
    end
  end
end
