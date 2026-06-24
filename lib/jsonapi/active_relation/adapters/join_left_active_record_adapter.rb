module JSONAPI
  module ActiveRelation
    module Adapters
      module JoinLeftActiveRecordAdapter
        def joins_left(*columns)
          ActiveSupport::Deprecation.warn "Prefer `left_joins`, JSONAPI::ActiveRelation::Adapters::JoinLeftActiveRecordAdapter will be removed in a future release"
          left_joins(columns)
        end

        alias_method :join_left, :joins_left
      end

      if defined?(ActiveRecord)
        ActiveRecord::Base.extend JoinLeftActiveRecordAdapter
      end
    end
  end
end