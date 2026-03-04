# frozen_string_literal: true

module JSONAPI
  module ActiveRelation
    module Adapters
      module JoinLeftActiveRecordAdapter
        # Extends left_joins functionality to rails 4, and uses the same logic for rails 5.0.x and 5.1.x
        # The default left_joins logic of rails 5.2.x is used. This results in and extra join in some cases. For
        # example Post.joins(:comments).joins_left(comments: :author) will join the comments table twice,
        # once inner and once left in 5.2, but only as inner in earlier versions.
        def joins_left(*columns)
          if ::Rails::VERSION::MAJOR >= 6 || (::Rails::VERSION::MAJOR >= 5 && ActiveRecord::VERSION::MINOR >= 2)
            left_joins(columns)
          else
            join_dependency = ActiveRecord::Associations::JoinDependency.new(self, columns, [])
            joins(join_dependency)
          end
         end

        alias_method :join_left, :joins_left
      end

      if defined?(ActiveRecord)
        ActiveRecord::Base.extend JoinLeftActiveRecordAdapter
      end
    end
  end
end
