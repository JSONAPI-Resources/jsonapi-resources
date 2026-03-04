# frozen_string_literal: true

module JSONAPI
  class Resource
    include ResourceCommon
    root_resource
    abstract
    immutable
  end
end
