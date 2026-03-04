# frozen_string_literal: true

module JSONAPI
  module Utils
    module PolymorphicTypesLookup
      extend self

      singleton_class.attr_accessor :build_polymorphic_types_lookup_strategy
      self.build_polymorphic_types_lookup_strategy =
        :build_polymorphic_types_lookup_from_object_space

      def polymorphic_types(name, rebuild: false)
        polymorphic_types_lookup(rebuild: rebuild).fetch(name.to_sym, &handle_polymorphic_type_name_found)
      end

      def handle_polymorphic_type_name_found
        @handle_polymorphic_type_name_found ||= lambda do |name|
          warn "[POLYMORPHIC TYPE NOT FOUND] No polymorphic types found for #{name}"
          nil
        end
      end

      def polymorphic_types_lookup(rebuild: false)
        polymorphic_types_lookup_clear! if rebuild
        @polymorphic_types_lookup ||= build_polymorphic_types_lookup
      end

      def polymorphic_types_lookup_clear!
        @polymorphic_types_lookup = nil
      end

      def build_polymorphic_types_lookup
        public_send(build_polymorphic_types_lookup_strategy)
      end

      def build_polymorphic_types_lookup_from_descendants
        {}.tap do |lookup|
          ActiveRecord::Base
            .descendants
            .select(&:name)
            .reject(&:abstract_class)
            .select(&:model_name).map {|klass|
              add_polymorphic_types_lookup(klass: klass, lookup: lookup)
            }
        end
      end

      def build_polymorphic_types_lookup_from_object_space
        {}.tap do |lookup|
          ObjectSpace.each_object do |klass|
            next unless Module === klass
            next unless ActiveRecord::Base > klass
            add_polymorphic_types_lookup(klass: klass, lookup: lookup)
          end
        end
      end

      # TODO(BF): Consider adding the following conditions
      # is_active_record_inspectable = true
      # is_active_record_inspectable &&= klass.respond_to?(:reflect_on_all_associations, true)
      # is_active_record_inspectable &&= format_polymorphic_klass_type(klass).present?
      # return unless is_active_record_inspectable
      def add_polymorphic_types_lookup(klass:, lookup:)
        klass.reflect_on_all_associations(:has_many).select { |r| r.options[:as] }.each do |reflection|
          (lookup[reflection.options[:as]] ||= []) << format_polymorphic_klass_type(klass).underscore
        end
      end

      # TODO(BF): Consider adding the following conditions
      # klass.name ||
      #   begin
      #     klass.model_name.name
      #   rescue ArgumentError => ex
      #     # klass.base_class may be nil
      #     warn "[POLYMORPHIC TYPE] #{__callee__} #{klass} #{ex.inspect}"
      #     nil
      #   end
      def format_polymorphic_klass_type(klass)
        klass.name
      end
    end
  end
end
