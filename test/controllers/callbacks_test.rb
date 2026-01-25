# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class TestCallbacksController < JSONAPI::ResourceController
  include JSONAPI::ActsAsResourceController

  # Define the callback to verify it runs and receives the object
  set_callback :process_operations, :after do |object|
    @callback_run = true
    @callback_object = object
  end

  attr_reader :callback_run, :callback_object

  # Stub render to avoid DoubleRenderError in this isolated test context
  def render(*args); end
end

class CallbacksTest < ActionController::TestCase
  def setup
    @controller = TestCallbacksController.new
    @request = ActionController::TestRequest.create(@controller)
    @response = ActionDispatch::TestResponse.new
    @controller.request = @request
    @controller.response = @response
  end

  def test_process_operations_callback_lifecycle
    # Trigger the action
    # We call process_request directly as in the previous reproduction study, or simulate index
    @controller.index

    # Verify callback ran
    assert @controller.callback_run, 'Callback should have been run after process_request'

    # Verify callback received the controller instance
    assert_equal @controller, @controller.callback_object, 'Callback should be passed the controller instance'
  end
end
