module JSONAPI
  # Rails 7.2 removed the global ActiveSupport::Deprecation.warn; a gem
  # warns through its own deprecator, which every supported Rails has.
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('0.10', 'jsonapi-resources')
  end
end
