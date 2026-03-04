require File.expand_path('../../../test_helper', __FILE__)

class CatResource < JSONAPI::Resource
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'

  filters :name

  def self.sortable_fields(context)
    super(context) << :"mother.name"
  end
end

class TreeResource < JSONAPI::Resource
  def self.sortable_field?(key, context)
    key =~ /^sort\d+/
  end
end

class JSONAPIRequestTest < ActiveSupport::TestCase
  def test_parse_includes_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso_currency'
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    assert request.errors.empty?
  end

  def test_check_include_allowed
    reset_includes
    JSONAPI::Request.new.check_include(ExpenseEntryResource, "isoCurrency".partition('.'))
  ensure
    reset_includes
  end

  def test_check_nested_include_allowed
    reset_includes
    JSONAPI::Request.new.check_include(ExpenseEntryResource, "employee.expenseEntries".partition('.'))
  ensure
    reset_includes
  end

  def test_check_include_relationship_does_not_exist
    reset_includes

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      assert JSONAPI::Request.new.check_include(ExpenseEntryResource, "foo".partition('.'))
    end
  ensure
    reset_includes
  end

  def test_check_nested_include_relationship_does_not_exist_wrong_format
    reset_includes

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::Request.new.check_include(ExpenseEntryResource, "employee.expense-entries".partition('.'))
    end
  ensure
    reset_includes
  end

  def test_check_include_has_one_not_allowed_default
    reset_includes

    JSONAPI::Request.new.check_include(ExpenseEntryResource, "isoCurrency".partition('.'))
    JSONAPI.configuration.default_allow_include_to_one = false

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::Request.new.check_include(ExpenseEntryResource, "isoCurrency".partition('.'))
    end
  ensure
      reset_includes
  end

  def test_check_include_has_one_not_allowed_resource
    reset_includes

    JSONAPI::Request.new.check_include(ExpenseEntryResource, "isoCurrency".partition('.'))
    ExpenseEntryResource._relationship(:iso_currency).allow_include = false

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::Request.new.check_include(ExpenseEntryResource, "isoCurrency".partition('.'))
    end
  ensure
    reset_includes
  end

  def test_check_include_has_many_not_allowed_default
    reset_includes

    JSONAPI::Request.new.check_include(EmployeeResource, "expenseEntries".partition('.'))
    JSONAPI.configuration.default_allow_include_to_many = false

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::Request.new.check_include(EmployeeResource, "expenseEntries".partition('.'))
    end
  ensure
    reset_includes
  end

  def test_check_include_has_many_not_allowed_resource
    reset_includes

    JSONAPI::Request.new.check_include(EmployeeResource, "expenseEntries".partition('.'))
    EmployeeResource._relationship(:expense_entries).allow_include = false

    assert_raises JSONAPI::Exceptions::InvalidInclude do
      JSONAPI::Request.new.check_include(EmployeeResource, "expenseEntries".partition('.'))
    end
  ensure
    reset_includes
  end

  def test_parse_dasherized_with_dasherized_include
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso-currency'
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_underscored_include
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        include: 'iso_currency'
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_include_directives(ExpenseEntryResource, params[:include])
    refute request.errors.empty?
    assert_equal 'iso_currency is not a valid includable relationship of expense-entries', request.errors[0].detail
  end

  def test_parse_fields_singular
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {expense_entry: 'iso_currency'}
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    e = assert_raises JSONAPI::Exceptions::InvalidResource do
      request.parse_fields(ExpenseEntryResource, params[:fields])
    end
    refute e.errors.empty?
    assert_equal 'expense_entry is not a valid resource.', e.errors[0].detail
  end

  def test_parse_fields_underscored
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {expense_entries: 'iso_currency'}
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:underscored_key)
      }
    )

    request.parse_fields(ExpenseEntryResource, params[:fields])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_dasherized_fields
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense-entries' => 'iso-currency'
        }
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    request.parse_fields(ExpenseEntryResource, params[:fields])
    assert request.errors.empty?
  end

  def test_parse_dasherized_with_underscored_fields
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense-entries' => 'iso_currency'
        }
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )

    e = assert_raises JSONAPI::Exceptions::InvalidField do
      request.parse_fields(ExpenseEntryResource, params[:fields])
    end
    refute e.errors.empty?
    assert_equal 'iso_currency is not a valid field for expense-entries.', e.errors[0].detail
  end

  def test_parse_dasherized_with_underscored_resource
    params = ActionController::Parameters.new(
      {
        controller: 'expense_entries',
        action: 'index',
        fields: {
          'expense_entries' => 'iso-currency'
        }
      }
    )

    request = JSONAPI::Request.new(
      params,
      {
        context: nil,
        key_formatter: JSONAPI::Formatter.formatter_for(:dasherized_key)
      }
    )
    e = assert_raises JSONAPI::Exceptions::InvalidResource do
      request.parse_fields(ExpenseEntryResource, params[:fields])
    end
    refute e.errors.empty?
    assert_equal 'expense_entries is not a valid resource.', e.errors[0].detail
  end

  def test_parse_filters_with_valid_filters
    setup_request
    filters = @request.parse_filters(CatResource, {name: 'Whiskers'})
    assert_equal(filters[:name], 'Whiskers')
    assert_equal(@request.errors, [])
  end

  def test_parse_filters_with_non_valid_filter
    setup_request
    e = assert_raises JSONAPI::Exceptions::FilterNotAllowed do
        @request.parse_filters(CatResource, {breed: 'Whiskers'}) # breed is not a set filter
    end
    assert_equal 'breed is not allowed.', e.errors[0].detail
  end

  def test_parse_filters_with_no_filters
    setup_request
    filters = @request.parse_filters(CatResource, nil)
    assert_equal(filters, {})
    assert_equal(@request.errors, [])
  end

  def test_parse_filters_with_invalid_filters_param
    setup_request
    filters = @request.parse_filters(CatResource, 'noeach') # String does not implement #each
    assert_equal(filters, {})
    assert_equal(@request.errors.count, 1)
    assert_equal(@request.errors.first.title, "Invalid filters syntax")
  end

  def test_parse_sort_with_valid_sorts
    setup_request
    sort_criteria = @request.parse_sort_criteria(CatResource, "-name")
    assert_equal(@request.errors, [])
    assert_equal(sort_criteria, [{:field=>"name", :direction=>:desc}])
  end

  def test_parse_sort_with_resource_validated_sorts
    setup_request
    e = assert_raises JSONAPI::Exceptions::InvalidSortCriteria do
      @request.parse_sort_criteria(TreeResource, "sort66,name")
    end
    assert_equal 'name is not a valid sort criteria for trees', e.errors[0].detail
  end

  def test_parse_sort_with_relationships
    setup_request
    sort_criteria = @request.parse_sort_criteria(CatResource, "-mother.name")
    assert_equal(@request.errors, [])
    assert_equal(sort_criteria, [{:field=>"mother.name", :direction=>:desc}])
  end

  private

  def setup_request
    @request = JSONAPI::Request.new
  end

  def reset_includes
    JSONAPI.configuration.json_key_format = :camelized_key
    JSONAPI.configuration.default_allow_include_to_one = true
    JSONAPI.configuration.default_allow_include_to_many = true
    ExpenseEntryResource._relationship(:iso_currency).allow_include = nil
    EmployeeResource._relationship(:expense_entries).allow_include = nil
  end
end
