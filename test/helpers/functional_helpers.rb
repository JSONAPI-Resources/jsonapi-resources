module Helpers
  module FunctionalHelpers
    # from http://jamieonsoftware.com/blog/entry/testing-restful-response-types
    # def assert_response_is(type, message = '')
    #   case type
    #     when :js
    #       check = [
    #         'text/javascript'
    #       ]
    #     when :json
    #       check = [
    #         'application/json',
    #         'text/json',
    #         'application/x-javascript',
    #         'text/x-javascript',
    #         'text/x-json'
    #       ]
    #     when :xml
    #       check = [ 'application/xml', 'text/xml' ]
    #     when :yaml
    #       check = [
    #         'text/yaml',
    #         'text/x-yaml',
    #         'application/yaml',
    #         'application/x-yaml'
    #       ]
    #     else
    #       if methods.include?('assert_response_types')
    #         check = assert_response_types
    #       else
    #         check = []
    #       end
    #   end
    #
    #   if @response.media_type
    #     ct = @response.media_type
    #   elsif methods.include?('assert_response_response')
    #     ct = assert_response_response
    #   else
    #     ct = ''
    #   end
    #
    #   begin
    #     assert check.include?(ct)
    #   rescue Test::Unit::AssertionFailedError
    #     raise Test::Unit::AssertionFailedError.new(build_message(message, "The response type is not ?", type.to_s))
    #   end
    # end

    # def assert_js_redirect_to(path)
    #   assert_response_is :js
    #   assert_match /#{"window.location.href = \"" + path + "\""}/, @response.body
    # end
    #
    def json_response
      JSON.parse(@response.body)
    end

    # JSON:API gives no meaning to the order of to-many linkage, so sort it before comparing responses
    def normalize_linkage_order(json)
      return json unless json.is_a?(Hash)

      json.deep_dup.tap do |normalized|
        resources = Array.wrap(normalized['data']) + Array.wrap(normalized['included'])
        resources.each { |resource| sort_to_many_linkage(resource) }
      end
    end

    private

    def sort_to_many_linkage(resource)
      (resource['relationships'] || {}).each_value do |relationship|
        relationship['data'].sort_by! { |r| [r['type'], r['id']] } if relationship['data'].is_a?(Array)
      end
    end
  end
end