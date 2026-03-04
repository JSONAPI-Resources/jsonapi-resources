require File.expand_path('../../../../test_helper', __FILE__)
require 'generators/jsonapi/controller_generator'

module JSONAPI
  class ControllerGeneratorTest < Rails::Generators::TestCase
    tests ControllerGenerator
    destination Rails.root.join('../controllers')
    setup :prepare_destination
    teardown :cleanup_destination_root

    def cleanup_destination_root
      FileUtils.rm_rf destination_root
    end

    test "controller is created" do
      run_generator ["post"]
      assert_file 'app/controllers/posts_controller.rb', /class PostsController < JSONAPI::ResourceController/
    end

    test "controller is created with namespace" do
      run_generator ["api/v1/post"]
      assert_file 'app/controllers/api/v1/posts_controller.rb', /class Api::V1::PostsController < JSONAPI::ResourceController/
    end
  end
end
