require File.expand_path('../../../test_helper', __FILE__)

class TranslationTest < ActiveSupport::TestCase
  setup do
    @original_locale = I18n.locale
  end

  teardown do
    I18n.locale = @original_locale
  end

  test "parameter_not_allowed translation is loaded correctly in another language" do
    I18n.with_locale(:pt) do
      I18n.backend.store_translations(:pt, {
        "jsonapi-resources": {
          exceptions: {
            parameter_not_allowed: {
              title: "Parâmetro não permitido",
              detail: "%{param} não permitido."
            }
          }
        }
      })

      param = "sort"
      exception = JSONAPI::Exceptions::ParameterNotAllowed.new(param).errors[0]
      expected_title = I18n.t("jsonapi-resources.exceptions.parameter_not_allowed.title")
      expected_detail = I18n.t("jsonapi-resources.exceptions.parameter_not_allowed.detail", param: param)

      assert_equal expected_title, exception.title
      assert_equal expected_detail, exception.detail
    end
  end
end