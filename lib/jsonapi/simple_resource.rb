# frozen_string_literal: true

require 'jsonapi/callbacks'
require 'jsonapi/configuration'

module JSONAPI
  class SimpleResource
    include ResourceCommon
    root_resource
    abstract
    immutable
  end
end
