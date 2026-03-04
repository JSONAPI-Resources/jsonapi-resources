require File.expand_path('../test_helper', __FILE__)

# Replace this with the code necessary to make your test fail.
class BugTest < Minitest::Test
  include Rack::Test::Methods

  def json_api_headers
    {'Accept' => JSONAPI::MEDIA_TYPE, 'CONTENT_TYPE' => JSONAPI::MEDIA_TYPE}
  end

  def teardown
    Individual.delete_all
    ContactMedium.delete_all
  end

  def test_find_party_via_contact_medium
    individual = Individual.create(name: 'test')
    contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
    fetched_party = contact_medium.party
    assert_same individual, fetched_party, "Expect an individual to have been found via contact medium model's relationship 'party'"
  end

  def test_get_individual
    individual = Individual.create(name: 'test')
    ContactMedium.create(party: individual, name: 'test contact medium')
    get "/individuals/#{individual.id}"
    assert_last_response_status 200
  end

  def test_get_party_via_contact_medium
    individual = Individual.create(name: 'test')
    contact_medium = ContactMedium.create(party: individual, name: 'test contact medium')
    get "/contact_media/#{contact_medium.id}/party"
    assert_last_response_status 200, "Expect an individual to have been found via contact medium resource's relationship 'party'"
  end

  private

  def assert_last_response_status(status, failure_reason=nil)
    if last_response.status != status
      json_response = JSON.parse(last_response.body)
      pp json_response
    end
    assert_equal status, last_response.status, failure_reason
  end

  def app
    Rails.application
  end
end
