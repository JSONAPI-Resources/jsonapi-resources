#!/usr/bin/env rake
# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList['test/**/*_test.rb']
end

task default: [:test]

desc 'Run benchmarks'
namespace :test do
  Rake::TestTask.new(:benchmark) do |t|
    t.pattern = 'test/benchmark/*_benchmark.rb'
  end
end

desc 'Test bug report template'
namespace :test do
  namespace :bug_report_template do
    task :rails_5 do
      puts 'Test bug report templates'
      jsonapi_resources_root = File.expand_path(__dir__)
      chdir_path = File.join(jsonapi_resources_root, 'lib', 'bug_report_templates')
      report_env = { 'SILENT' => 'true', 'JSONAPI_RESOURCES_PATH' => jsonapi_resources_root }
      Bundler.with_clean_env do
        Dir.chdir(chdir_path) do
          abort('bug report template rails_5_master fails') unless system(report_env, Gem.ruby, 'rails_5_master.rb')
        end
      end
    end
  end
end
