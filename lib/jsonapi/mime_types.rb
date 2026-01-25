# frozen_string_literal: true

require 'json'

module JSONAPI
  MEDIA_TYPE = 'application/vnd.api+json'

  module MimeTypes
    def self.install
      Mime::Type.register JSONAPI::MEDIA_TYPE, :api_json

      parsers = ActionDispatch::Request.parameter_parsers.merge(
        Mime::Type.lookup(JSONAPI::MEDIA_TYPE).symbol => parser
      )
      ActionDispatch::Request.parameter_parsers = parsers
    end

    def self.parser
      lambda do |body|
        begin
          data = JSON.parse(body)
          if data.is_a?(Hash)
            data.with_indifferent_access
          else
            fail JSONAPI::Exceptions::InvalidRequestFormat.new
          end
        rescue JSON::ParserError => e
          { _parser_exception: JSONAPI::Exceptions::BadRequest.new(e.to_s) }
        rescue => e
          { _parser_exception: e }
        end
      end
    end
  end

  MimeTypes.install
end
