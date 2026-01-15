module JSONAPI
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('1.0', 'jsonapi-resources')
  end
end
