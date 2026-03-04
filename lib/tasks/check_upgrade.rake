# frozen_string_literal: true

require 'rake'
require 'jsonapi-resources'

namespace :jsonapi do
  namespace :resources do
    desc 'Checks application for orphaned overrides'
    task :check_upgrade => :environment do
      ::Rails.application.eager_load!

      resource_klasses = ObjectSpace.each_object(Class).select { |klass| klass.included_modules.include?(JSONAPI::ResourceCommon)}

      puts "Checking #{resource_klasses.count} resources"

      issues_found = 0

      klasses_with_deprecated = resource_klasses.select { |klass| klass.methods.include?(:find_records) }
      unless klasses_with_deprecated.empty?
        puts "  Found the following resources the still implement `find_records`:"
        klasses_with_deprecated.each { |klass| puts "    #{klass}"}
        puts "  The `find_records` method is no longer called by JR. Please review and ensure your functionality is ported over."

        issues_found = issues_found + klasses_with_deprecated.length
      end

      klasses_with_deprecated = resource_klasses.select { |klass| klass.methods.include?(:records_for) }
      unless klasses_with_deprecated.empty?
        puts "  Found the following resources the still implement `records_for`:"
        klasses_with_deprecated.each { |klass| puts "    #{klass}"}
        puts "  The `records_for` method is no longer called by JR. Please review and ensure your functionality is ported over."

        issues_found = issues_found + klasses_with_deprecated.length
      end

      klasses_with_deprecated = resource_klasses.select { |klass| klass.methods.include?(:apply_includes) }
      unless klasses_with_deprecated.empty?
        puts "  Found the following resources the still implement `apply_includes`:"
        klasses_with_deprecated.each { |klass| puts "    #{klass}"}
        puts "  The `apply_includes` method is no longer called by JR. Please review and ensure your functionality is ported over."

        issues_found = issues_found + klasses_with_deprecated.length
      end

      if issues_found > 0
        puts "Finished inspection. #{issues_found} issues found that may impact upgrading. Please address these issues. "
      else
        puts "Finished inspection with no issues found. Note this is only a cursory check for method overrides that will no \n" \
             "longer be called by JSONAPI::Resources. This check in no way assures your code will continue to function as \n" \
             "it did before the upgrade. Please do adequate testing before using in production."
      end
    end
  end
end
