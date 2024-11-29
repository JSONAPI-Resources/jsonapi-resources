require 'active_record'
require 'jsonapi-resources'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
end

### DATABASE
ActiveRecord::Schema.define do
  create_table :people, force: true do |t|
    t.string     :name
    t.string     :email
    t.datetime   :date_joined
    t.belongs_to :preferences
    t.integer    :hair_cut_id, index: true
    t.boolean    :book_admin, default: false
    t.boolean    :special, default: false
    t.timestamps null: false
  end

  create_table :author_details, force: true do |t|
    t.integer :person_id
    t.string  :author_stuff
    t.timestamps null: false
  end

  create_table :posts, force: true do |t|
    t.string     :title
    t.text       :body
    t.integer    :author_id
    t.integer    :parent_post_id
    t.belongs_to :section, index: true
    t.timestamps null: false
  end

  create_table :comments, force: true do |t|
    t.text       :body
    t.belongs_to :post, index: true
    t.integer    :author_id
    t.timestamps null: false
  end

  create_table :companies, force: true do |t|
    t.string     :type
    t.string     :name
    t.string     :address
    t.timestamps null: false
  end

  create_table :tags, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :sections, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :posts_tags, force: true do |t|
    t.references :post, :tag, index: true
  end
  add_index :posts_tags, [:post_id, :tag_id], unique: true

  create_table :special_post_tags, force: true do |t|
    t.references :post, :tag, index: true
  end
  add_index :special_post_tags, [:post_id, :tag_id], unique: true

  create_table :comments_tags, force: true do |t|
    t.references :comment, :tag, index: true
  end

  create_table :iso_currencies, id: false, force: true do |t|
    t.string :code, limit: 3, null: false
    t.string :name
    t.string :country_name
    t.string :minor_unit
    t.timestamps null: false
  end
  add_index :iso_currencies, :code, unique: true

  create_table :expense_entries, force: true do |t|
    t.string :currency_code, limit: 3, null: false
    t.integer :employee_id, null: false
    t.decimal :cost, precision: 12, scale: 4, null: false
    t.date :transaction_date
    t.timestamps null: false
  end

  create_table :planets, force: true do |t|
    t.string :name
    t.string :description
    t.integer :planet_type_id
  end

  create_table :planets_tags, force: true do |t|
    t.references :planet, :tag, index: true
  end
  add_index :planets_tags, [:planet_id, :tag_id], unique: true

  create_table :planet_types, force: true do |t|
    t.string :name
  end

  create_table :moons, force: true do |t|
    t.string  :name
    t.string  :description
    t.integer :planet_id
    t.timestamps null: false
  end

  create_table :craters, id: false, force: true do |t|
    t.string  :code
    t.string  :description
    t.integer :moon_id
    t.timestamps null: false
  end

  create_table :preferences, force: true do |t|
    t.integer :person_id
    t.boolean :advanced_mode, default: false
    t.string  :nickname
    t.timestamps null: false
  end

  create_table :facts, force: true do |t|
    t.integer  :person_id
    t.string   :spouse_name
    t.text     :bio
    t.float    :quality_rating
    t.decimal  :salary, precision: 12, scale: 2
    t.datetime :date_time_joined
    t.date     :birthday
    t.time     :bedtime
    t.binary   :photo, limit: 1.kilobyte
    t.boolean  :cool
    t.timestamps null: false
  end

  create_table :books, force: true do |t|
    t.string :title
    t.string :isbn
    t.boolean :banned, default: false
    t.boolean :fiction, default: false
    t.timestamps null: false
  end

  create_table :book_authors, force: true do |t|
    t.integer :book_id
    t.integer :person_id
  end

  create_table :book_comments, force: true do |t|
    t.text       :body
    t.belongs_to :book, index: true
    t.integer    :author_id
    t.boolean    :approved, default: true
    t.timestamps null: false
  end

  create_table :customers, force: true do |t|
    t.string   :name
    t.timestamps null: false
  end

  create_table :purchase_orders, force: true do |t|
    t.date     :order_date
    t.date     :requested_delivery_date
    t.date     :delivery_date
    t.integer  :customer_id
    t.string   :delivery_name
    t.string   :delivery_address_1
    t.string   :delivery_address_2
    t.string   :delivery_city
    t.string   :delivery_state
    t.string   :delivery_postal_code
    t.float    :delivery_fee
    t.float    :tax
    t.float    :total
    t.timestamps null: false
  end

  create_table :order_flags, force: true do |t|
    t.string :name
  end

  create_table :purchase_orders_order_flags, force: true do |t|
    t.references :purchase_order, :order_flag, index: true
  end
  add_index :purchase_orders_order_flags, [:purchase_order_id, :order_flag_id], unique: true, name: "po_flags_idx"

  create_table :line_items, force: true do |t|
    t.integer  :purchase_order_id
    t.string   :part_number
    t.string   :quantity
    t.float    :item_cost
    t.timestamps null: false
  end

  create_table :hair_cuts, force: true do |t|
    t.string :style
  end

  create_table :numeros_telefone, force: true do |t|
    t.string   :numero_telefone
    t.timestamps null: false
  end

  create_table :categories, force: true do |t|
    t.string :name
    t.string :status, limit: 10
    t.timestamps null: false
  end

  create_table :pictures, force: true do |t|
    t.string  :name
    t.integer :imageable_id
    t.string  :imageable_type
    t.timestamps null: false
  end

  create_table :documents, force: true do |t|
    t.string  :name
    t.timestamps null: false
  end

  create_table :products, force: true do |t|
    t.string  :name
    t.timestamps null: false
  end

  create_table :vehicles, force: true do |t|
    t.string :type
    t.string :make
    t.string :model
    t.string :length_at_water_line
    t.string :drive_layout
    t.string :serial_number
    t.integer :person_id
    t.timestamps null: false
  end

  create_table :makes, force: true do |t|
    t.string :model
    t.timestamps null: false
  end

  # special cases - fields that look like they should be reserved names
  create_table :hrefs, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :links, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :web_pages, force: true do |t|
    t.string :href
    t.string :link
    t.timestamps null: false
  end

  create_table :questionables, force: true do |t|
    t.timestamps null: false
  end

  create_table :boxes, force: true  do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :things, force: true  do |t|
    t.string :name
    t.references :user
    t.references :box

    t.timestamps null: false
  end

  create_table :users, force: true  do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :related_things, force: true  do |t|
    t.string :name
    t.references :from, references: :thing
    t.references :to, references: :thing

    t.timestamps null: false
  end

  create_table :questions, force: true do |t|
    t.string :text
  end

  create_table :answers, force: true do |t|
    t.references :question
    t.integer :respondent_id
    t.string  :respondent_type
    t.string :text
  end

  create_table :patients, force: true do |t|
    t.string :name
  end

  create_table :doctors, force: true do |t|
    t.string :name
  end

  create_table :painters, force: true do |t|
    t.string :name

    t.timestamps null: false
  end

  create_table :paintings, force: true do |t|
    t.string :title
    t.string :category
    t.belongs_to :painter

    t.timestamps null: false
  end

  create_table :collectors, force: true do |t|
    t.string :name
    t.belongs_to :painting
  end

  create_table :lists, force: true do |t|
    t.string :name
  end

  create_table :list_items, force: true do |t|
    t.belongs_to :list
  end
  # special cases
end

### MODELS
class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  has_many :vehicles
  belongs_to :preferences
  belongs_to :hair_cut
  has_one :author_detail

  has_and_belongs_to_many :books, join_table: :book_authors

  has_many :even_posts, -> { where('posts.id % 2 = 0') }, class_name: 'Post', foreign_key: 'author_id'
  has_many :odd_posts, -> { where('posts.id % 2 = 1') }, class_name: 'Post', foreign_key: 'author_id'

  ### Validations
  validates :name, presence: true
  validates :date_joined, presence: true
end

class AuthorDetail < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'person_id'
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :writer, class_name: 'Person', foreign_key: 'author_id'
  has_many :comments
  has_and_belongs_to_many :tags, join_table: :posts_tags
  has_many :special_post_tags
  has_many :special_tags, through: :special_post_tags, source: :tag
  belongs_to :section
  has_one :parent_post, class_name: 'Post', foreign_key: 'parent_post_id'

  validates :author, presence: true
  validates :title, length: { maximum: 35 }

  before_destroy :destroy_callback

  def destroy_callback
    if title == "can't destroy me"
      errors.add(:title, "can't destroy me")

      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
      # :nocov:
    end
  end
end

class SpecialPostTag < ActiveRecord::Base
  belongs_to :tag
  belongs_to :post
end

class Comment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :post
  has_and_belongs_to_many :tags, join_table: :comments_tags
end

class Company < ActiveRecord::Base
end

class Firm < Company
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, join_table: :posts_tags
  has_and_belongs_to_many :planets, join_table: :planets_tags
end

class Section < ActiveRecord::Base
  has_many :posts
end

class HairCut < ActiveRecord::Base
  has_many :people
end

class Property < ActiveRecord::Base
end

class Customer < ActiveRecord::Base
end

class BadlyNamedAttributes < ActiveRecord::Base
end

class Cat < ActiveRecord::Base
end

class IsoCurrency < ActiveRecord::Base
  self.primary_key = :code
  # has_many :expense_entries, foreign_key: 'currency_code'
end

class ExpenseEntry < ActiveRecord::Base
  belongs_to :employee, class_name: 'Person', foreign_key: 'employee_id'
  belongs_to :iso_currency, foreign_key: 'currency_code'
end

class Planet < ActiveRecord::Base
  has_many :moons
  belongs_to :planet_type

  has_and_belongs_to_many :tags, join_table: :planets_tags

  # Test model callback cancelling save
  before_save :check_not_pluto

  def check_not_pluto
    # Pluto can't be a planet, so cancel the save
    if name.downcase == 'pluto'
      # :nocov:
      if Rails::VERSION::MAJOR >= 5
        throw(:abort)
      else
        return false
      end
      # :nocov:
    end
  end
end

class PlanetType < ActiveRecord::Base
  has_many :planets
end

class Moon < ActiveRecord::Base
  belongs_to :planet

  has_many :craters
end

class Crater < ActiveRecord::Base
  self.primary_key = :code

  belongs_to :moon
end

class Preferences < ActiveRecord::Base
  has_one :author, class_name: 'Person', :inverse_of => 'preferences'
end

class Fact < ActiveRecord::Base
  validates :spouse_name, :bio, presence: true
end

class Like < ActiveRecord::Base
end

class Breed

  def initialize(id = nil, name = nil)
    if id.nil?
      @id = $breed_data.new_id
      $breed_data.add(self)
    else
      @id = id
    end
    @name = name
    @errors = ActiveModel::Errors.new(self)
  end

  attr_accessor :id, :name

  def destroy
    $breed_data.remove(@id)
  end

  def valid?(context = nil)
    @errors.clear
    if name.is_a?(String) && name.length > 0
      return true
    else
      @errors.add(:name, "can't be blank")
      return false
    end
  end

  def errors
    @errors
  end
end

class Book < ActiveRecord::Base
  has_many :book_comments
  has_many :approved_book_comments, -> { where(approved: true) }, class_name: "BookComment"

  has_and_belongs_to_many :authors, join_table: :book_authors, class_name: "Person"
end

class BookComment < ActiveRecord::Base
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :book

  def self.for_user(current_user)
    records = self
    # Hide the unapproved comments from people who are not book admins
    unless current_user && current_user.book_admin
      records = records.where(approved: true)
    end
    records
  end
end

class BreedData
  def initialize
    @breeds = {}
  end

  def breeds
    @breeds
  end

  def new_id
    @breeds.keys.max + 1
  end

  def add(breed)
    @breeds[breed.id] = breed
  end

  def remove(id)
    @breeds.delete(id)
  end
end

class Customer < ActiveRecord::Base
  has_many :purchase_orders
end

class PurchaseOrder < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
  has_many :admin_line_items, class_name: 'LineItem', foreign_key: 'purchase_order_id'

  has_and_belongs_to_many :order_flags, join_table: :purchase_orders_order_flags

  has_and_belongs_to_many :admin_order_flags, join_table: :purchase_orders_order_flags, class_name: 'OrderFlag'
end

class OrderFlag < ActiveRecord::Base
  has_and_belongs_to_many :purchase_orders, join_table: :purchase_orders_order_flags
end

class LineItem < ActiveRecord::Base
  belongs_to :purchase_order
end

class NumeroTelefone < ActiveRecord::Base
end

class Category < ActiveRecord::Base
end

class Picture < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true
end

class Vehicle < ActiveRecord::Base
  belongs_to :person
end

class Car < Vehicle
end

class Boat < Vehicle
end

class Document < ActiveRecord::Base
  has_many :pictures, as: :imageable
end

class Document::Topic < Document
end

class Product < ActiveRecord::Base
  has_one :picture, as: :imageable
end

class Make < ActiveRecord::Base
end

class WebPage < ActiveRecord::Base
end

class Box < ActiveRecord::Base
  has_many :things
end

class User < ActiveRecord::Base
  has_many :things
end

class Thing < ActiveRecord::Base
  belongs_to :box
  belongs_to :user

  has_many :related_things, foreign_key: :from_id
  has_many :things, through: :related_things, source: :to
end

class RelatedThing < ActiveRecord::Base
  belongs_to :from, class_name: "Thing", foreign_key: :from_id
  belongs_to :to, class_name: "Thing", foreign_key: :to_id
end

class Question < ActiveRecord::Base
  has_one :answer

  def respondent
    answer.try(:respondent)
  end
end

class Answer < ActiveRecord::Base
  belongs_to :question
  belongs_to :respondent, polymorphic: true
end

class Patient < ActiveRecord::Base
end

class Doctor < ActiveRecord::Base
end

module Api
  module V7
    class Client < Customer
    end

    class Customer < Customer
    end
  end
end

class Painter < ActiveRecord::Base
  has_many :paintings
end

class Painting < ActiveRecord::Base
  belongs_to :painter
  has_many :collectors
end

class Collector < ActiveRecord::Base
  belongs_to :painting
end

class List < ActiveRecord::Base
  has_many :items, class_name: 'ListItem', inverse_of: :list
end

class ListItem < ActiveRecord::Base
  belongs_to :list, inverse_of: :items
end

### CONTROLLERS
class AuthorsController < JSONAPI::ResourceControllerMetal
end

class AuthorDetailsController < JSONAPI::ResourceControllerMetal
end

class PeopleController < JSONAPI::ResourceController
end

class BaseController < ActionController::Base
  include JSONAPI::ActsAsResourceController
end

class PostsController < BaseController

  class SpecialError < StandardError; end
  class SubSpecialError < PostsController::SpecialError; end
  class SerializeError < StandardError; end

  # This is used to test that classes that are whitelisted are reraised by
  # the operations dispatcher.
  rescue_from PostsController::SpecialError do
    head :forbidden
  end

  def handle_exceptions(e)
    case e
      when PostsController::SpecialError
        raise e
      else
        super(e)
    end
  end

  #called by test_on_server_error
  def self.set_callback_message(error)
    @callback_message = "Sent from method"
  end

  def resource_serializer_klass
    PostSerializer
  end
end

class PostSerializer < JSONAPI::ResourceSerializer
  def initialize(*)
    if $PostSerializerRaisesErrors
      raise PostsController::SerializeError
    else
      super
    end
  end
end

class CommentsController < JSONAPI::ResourceController
end

class FirmsController < JSONAPI::ResourceController
end

class SectionsController < JSONAPI::ResourceController
end

class TagsController < JSONAPI::ResourceController
end

class IsoCurrenciesController < JSONAPI::ResourceController
end

class ExpenseEntriesController < JSONAPI::ResourceController
end

class BreedsController < JSONAPI::ResourceController
end

class FactsController < JSONAPI::ResourceController
end

class CategoriesController < JSONAPI::ResourceController
end

class PicturesController < JSONAPI::ResourceController
end

class DocumentsController < JSONAPI::ResourceController
end

class ProductsController < JSONAPI::ResourceController
end

class ImageablesController < JSONAPI::ResourceController
end

class VehiclesController < JSONAPI::ResourceController
end

class CarsController < JSONAPI::ResourceController
end

class BoatsController < JSONAPI::ResourceController
end

class BooksController < JSONAPI::ResourceController
  def context
    { title: 'Title' }
  end
end

### CONTROLLERS
module Api
  module V1
    class AuthorsController < JSONAPI::ResourceController
    end

    class PeopleController < JSONAPI::ResourceController
    end

    class PostsController < ActionController::Base
      include JSONAPI::ActsAsResourceController
    end

    class TagsController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class BreedsController < JSONAPI::ResourceController
    end

    class PlanetsController < JSONAPI::ResourceController
    end

    class PlanetTypesController < JSONAPI::ResourceController
    end

    class MoonsController < JSONAPI::ResourceController
    end

    class CratersController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end

    class LikesController < JSONAPI::ResourceController
    end
  end

  module V2
    class AuthorsController < JSONAPI::ResourceController
    end

    class PeopleController < JSONAPI::ResourceController
    end

    class CommentsController < JSONAPI::ResourceController
    end

    class PostsController < JSONAPI::ResourceController
    end

    class PreferencesController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end

    class BooksController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end

    class BookCommentsController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end
  end

  module V3
    class PostsController < JSONAPI::ResourceController
    end
  end

  module V4
    class PostsController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end

    class BooksController < JSONAPI::ResourceController
    end
  end

  module V5
    class AuthorsController < JSONAPI::ResourceController
      def serialization_options
        {foo: 'bar'}
      end
    end

    class PostsController < JSONAPI::ResourceController
    end

    class ExpenseEntriesController < JSONAPI::ResourceController
    end

    class IsoCurrenciesController < JSONAPI::ResourceController
    end

    class PaintersController < JSONAPI::ResourceController
    end

    class CollectorsController < JSONAPI::ResourceController
    end
  end

  module V6
    class PostsController < JSONAPI::ResourceController
    end

    class SectionsController < JSONAPI::ResourceController
    end

    class CustomersController < JSONAPI::ResourceController
    end

    class PurchaseOrdersController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end

    class LineItemsController < JSONAPI::ResourceController
    end

    class OrderFlagsController < JSONAPI::ResourceController
    end
  end

  module V7
    class CustomersController < JSONAPI::ResourceController
    end

    class PurchaseOrdersController < JSONAPI::ResourceController
    end

    class LineItemsController < JSONAPI::ResourceController
    end

    class OrderFlagsController < JSONAPI::ResourceController
    end

    class CategoriesController < JSONAPI::ResourceController
    end

    class ClientsController < JSONAPI::ResourceController
    end
  end

  module V8
    class NumerosTelefoneController < JSONAPI::ResourceController
    end
  end

  module V9
    class PeopleController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end

    class PreferencesController < JSONAPI::ResourceController
      def context
        {current_user: $test_user}
      end
    end
  end
end

module Api
  class BoxesController < JSONAPI::ResourceController
  end
end

class QuestionsController < JSONAPI::ResourceController
end

class AnswersController < JSONAPI::ResourceController
end

class PatientsController < JSONAPI::ResourceController
end

class DoctorsController < JSONAPI::ResourceController
end

class RespondentController < JSONAPI::ResourceController
end

class ListsController < JSONAPI::ResourceController
end

class ListItemsController < JSONAPI::ResourceController
end

### RESOURCES
class BaseResource < JSONAPI::Resource
  abstract
end

class PersonResource < BaseResource
  attributes :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments
  has_many :posts
  has_many :vehicles, polymorphic: true

  has_one :preferences
  has_one :hair_cut

  filter :name, verify: :verify_name_filter

  def self.verify_name_filter(values, _context)
    values.each do |value|
      if value.length < 3
        raise JSONAPI::Exceptions::InvalidFilterValue.new(:name, value)
      end
    end
    return values
  end

end

class PersonWithEvenAndOddPostResource < JSONAPI::Resource
  model_name 'Person'

  has_many :even_posts, foreign_key: 'author_id', class_name: 'Post', relation_name: :even_posts
  has_many :odd_posts, foreign_key: 'author_id', class_name: 'Post', relation_name: :odd_posts
end

class SpecialBaseResource < BaseResource
  abstract

  model_hint model: Person, resource: :special_person
end

class SpecialPersonResource < SpecialBaseResource
  model_name 'Person'

  def self.records(options = {})
    Person.where(special: true)
  end
end

class VehicleResource < JSONAPI::Resource
  immutable

  has_one :person
  attributes :make, :model, :serial_number
end

class CarResource < VehicleResource
  model_name "Car"
  attributes :drive_layout
end

class BoatResource < VehicleResource
  model_name "Boat"
  attributes :length_at_water_line
end

class CommentResource < JSONAPI::Resource
  attributes :body
  has_one :post
  has_one :author, class_name: 'Person'
  has_many :tags

  filters :body
end

class CompanyResource < JSONAPI::Resource
  attributes :name, :address
end

class FirmResource < CompanyResource
  model_name "Firm"
end

class TagResource < JSONAPI::Resource
  attributes :name

  has_many :posts
  filter :name
  # Not including the planets relationship so they don't get output
  #has_many :planets
end

class SectionResource < JSONAPI::Resource
  attributes 'name'
end

module ParentApi
  class PostResource < JSONAPI::Resource
    model_name 'Post'
    attributes :title
    has_one :parent_post
  end
end

class PostResource < JSONAPI::Resource
  attribute :title
  attribute :body
  attribute :subject

  has_one :author, class_name: 'Person'
  has_one :section
  has_many :tags, acts_as_set: true, inverse_relationship: :posts, eager_load_on_include: false
  has_many :comments, acts_as_set: false, inverse_relationship: :post

  # Not needed - just for testing
  primary_key :id

  def self.default_sort
    [{field: 'title', direction: :desc}, {field: 'id', direction: :desc}]
  end

  before_save do
    msg = "Before save"
  end

  after_save do
    msg = "After save"
  end

  before_update do
    msg = "Before update"
  end

  after_update do
    msg = "After update"
  end

  before_replace_fields do
    msg = "Before replace_fields"
  end

  after_replace_fields do
    msg = "After replace_fields"
  end

  around_update :around_update_check

  def around_update_check
    # do nothing
    yield
    # do nothing
  end

  def subject
    @model.title
  end

  def title=(title)
    @model.title = title
    if title == 'BOOM'
      raise 'The Server just tested going boom. If this was a real emergency you would be really dead right now.'
    end
  end

  filters :title, :author, :tags, :comments
  filter :id, verify: ->(values, context) {
    verify_keys(values, context)
    return values
  }
  filter :ids,
         verify: ->(values, context) {
           verify_keys(values, context)
           return values
         },
         apply: -> (records, value, _options) {
           records.where('id IN (?)', value)
         }

  filter :search,
    verify: ->(values, context) {
      values.all?{|v| (v.is_a?(Hash) || v.is_a?(ActionController::Parameters)) } && values
    },
    apply: -> (records, values, _options) {
      records.where(title: values.first['title'])
    }

  def self.updatable_fields(context)
    super(context) - [:author, :subject]
  end

  def self.creatable_fields(context)
    super(context) - [:subject]
  end

  def self.sortable_fields(context)
    super(context) - [:id] + [:"author.name"]
  end

  def self.verify_key(key, context = nil)
    super(key)
    raise JSONAPI::Exceptions::RecordNotFound.new(key) unless find_by_key(key, context: context)
    return key
  end
end

class HairCutResource < JSONAPI::Resource
  attribute :style
  has_many :people
end

class IsoCurrencyResource < JSONAPI::Resource
  attributes :name, :country_name, :minor_unit

  def self.creatable_fields(_context = nil)
    super + [:id]
  end

  filter :country_name

  key_type :string
end

class ExpenseEntryResource < JSONAPI::Resource
  attributes :cost
  attribute :transaction_date, format: :date

  has_one :iso_currency, foreign_key: 'currency_code'
  has_one :employee, class_name: 'Person'
end

class EmployeeResource < JSONAPI::Resource
  attributes :name, :email
  model_name 'Person'
end

class BreedResource < JSONAPI::Resource
  attribute :name, format: :title

  # This is unneeded, just here for testing
  routing_options param: :id

  def self.find(filters, options = {})
    breeds = []
    $breed_data.breeds.values.each do |breed|
      breeds.push(BreedResource.new(breed, options[:context]))
    end
    breeds
  end

  def self.find_by_key(id, options = {})
    BreedResource.new($breed_data.breeds[id.to_i], options[:context])
  end

  def _save
    super
    return :accepted
  end
end

class PlanetResource < JSONAPI::Resource
  attribute :name
  attribute :description

  has_many :moons
  has_one :planet_type

  has_many :tags, acts_as_set: true
end

class PropertyResource < JSONAPI::Resource
  attributes :name

  has_many :planets
end

class PlanetTypeResource < JSONAPI::Resource
  attributes :name
  has_many :planets, inverse_relationship: :planet_type
end

class MoonResource < JSONAPI::Resource
  attribute :name
  attribute :description

  has_one :planet
  has_many :craters
end

class CraterResource < JSONAPI::Resource
  attribute :code
  attribute :description

  has_one :moon

  filter :description, apply: -> (records, value, options) {
    fail "context not set" unless options[:context][:current_user] != nil && options[:context][:current_user] == $test_user
    records.where(:description => value)
  }

  def self.verify_key(key, context = nil)
    key && String(key)
  end
end

class PreferencesResource < JSONAPI::Resource
  attribute :advanced_mode

  singleton singleton_key: -> (context) {
    key = context[:current_user].try(:preferences).try(:id)
    raise JSONAPI::Exceptions::RecordNotFound.new(nil) if key.nil?
    key
  }

  has_one :author, :foreign_key_on => :related

  def self.find_records(filters, options = {})
    Preferences.limit(1)
  end
end

class FactResource < JSONAPI::Resource
  attribute :spouse_name
  attribute :bio
  attribute :quality_rating
  attribute :salary
  attribute :date_time_joined
  attribute :birthday
  attribute :bedtime
  attribute :photo
  attribute :cool
end

class CategoryResource < JSONAPI::Resource
  filter :status, default: 'active'
end

class PictureResource < JSONAPI::Resource
  attribute :name
  has_one :imageable, polymorphic: true
end

class DocumentResource < JSONAPI::Resource
  attribute :name
  has_many :pictures
end

class TopicResource < JSONAPI::Resource
  model_name 'Document::Topic'
  has_many :pictures
end

class ProductResource < JSONAPI::Resource
  attribute :name
  has_one :picture, always_include_linkage_data: true

  def picture_id
    _model.picture.id
  end
end

class ImageableResource < JSONAPI::Resource
end

class MakeResource < JSONAPI::Resource
  attribute :model
end

class WebPageResource < JSONAPI::Resource
  attribute :href
  attribute :link
end

class AuthorResource < JSONAPI::Resource
  model_name 'Person'
  attributes :name

  has_one :author_detail, :foreign_key_on => :related
  has_many :books, inverse_relationship: :authors
  has_one :preference
end

class BookResource < JSONAPI::Resource
  attribute :title

  has_many :authors, class_name: 'Author', inverse_relationship: :books

  def title
    context[:title]
  end
end

class AuthorDetailResource < JSONAPI::Resource
  attributes :author_stuff
  has_one :author, foreign_key: 'person_id', class_name: 'Person'
end

class SimpleCustomLinkResource < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    { raw: options[:serializer].link_builder.self_link(self) + "/raw" }
  end
end

class CustomLinkWithRelativePathOptionResource < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    { raw: options[:serializer].link_builder.self_link(self) + "/super/duper/path.xml" }
  end
end

class CustomLinkWithIfCondition < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    if title == "JR Solves your serialization woes!"
      {conditional_custom_link: options[:serializer].link_builder.self_link(self) + "/conditional/link.json"}
    end
  end
end

class CustomLinkWithLambda < JSONAPI::Resource
  model_name 'Post'
  attributes :title, :body, :subject, :created_at

  def subject
    @model.title
  end

  has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
  has_one :section
  has_many :comments, acts_as_set: false

  filters :writer

  def custom_links(options)
    {
      link_to_external_api: "http://external-api.com/posts/#{ created_at.year }/#{ created_at.month }/#{ created_at.day }-#{ subject.gsub(' ', '-') }"
    }
  end
end

module Api
  module V1
    class WriterResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      has_many :posts

      filter :name
    end

    class LikeResource < JSONAPI::Resource
    end

    class PostResource < JSONAPI::Resource
      # V1 no longer supports tags and now calls author 'writer'
      attribute :title
      attribute :body
      attribute :subject

      has_one :writer, foreign_key: 'author_id', class_name: 'Writer'
      has_one :section
      has_many :comments, acts_as_set: false

      def self.default_sort
        [{field: 'title', direction: :asc}, {field: 'id', direction: :desc}]
      end

      def subject
        @model.title
      end

      filters :writer

      def custom_links(options)
        self_link = options[:serializer].link_builder.self_link(self)
        self_link ||= ''
        {
          'self' => self_link + '?secret=true',
          'raw' => self_link + "/raw"
        }
      end
    end

    class PersonResource < PersonResource; end
    class CommentResource < CommentResource; end
    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class BreedResource < BreedResource; end
    class PlanetResource < PlanetResource; end
    class PlanetTypeResource < PlanetTypeResource; end
    class MoonResource < MoonResource; end
    class CraterResource < CraterResource; end
    class PreferencesResource < PreferencesResource; end
    class EmployeeResource < EmployeeResource; end
    class HairCutResource < HairCutResource; end
    class VehicleResource < VehicleResource; end
    class CarResource < CarResource; end
    class BoatResource < BoatResource; end
  end
end

module Api
  module V2
    class PreferencesResource < PreferencesResource; end
    class PersonResource < PersonResource; end
    class CommentResource < CommentResource; end
    class PostResource < PostResource; end
    class AuthorResource < AuthorResource; end
    class VehicleResource < VehicleResource; end
    class CarResource < CarResource; end
    class BoatResource < BoatResource; end
    class HairCutResource < HairCutResource; end
    class TagResource < TagResource; end
    class SectionResource < SectionResource; end

    class BookResource < JSONAPI::Resource
      attribute "title"
      attributes :isbn, :banned, :fiction

      paginator :offset

      has_many "authors"

      has_many "book_comments", relation_name: -> (options = {}) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        unless current_user && current_user.book_admin
          :approved_book_comments
        else
          :book_comments
        end
      }, reflect: true

      has_many "aliased_comments", class_name: 'BookComments', relation_name: :approved_book_comments

      filters :book_comments
      filter :banned, apply: :apply_filter_banned
      filter :fiction, apply: :apply_filter_fiction

      class << self
        def books
          Book.arel_table
        end

        def not_banned_books
          books[:banned].eq(false)
        end

        def records(options = {})
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          records = _model_class
          # Hide the banned books from people who are not book admins
          unless current_user && current_user.book_admin
            records = records.where(not_banned_books)
          end
          records
        end

        def apply_filter_banned(records, value, options)
          context = options[:context]
          current_user = context ? context[:current_user] : nil

          # Only book admins might filter for banned books
          if current_user && current_user.book_admin
            records.where('books.banned = ?', value[0] == 'true')
          else
            records
          end
        end

        def apply_filter_fiction(records, value, _options)
          records.where('books.fiction = ?', value[0] == 'true')
        end
      end
    end

    class BookCommentResource < JSONAPI::Resource
      attributes :body, :approved

      has_one :book
      has_one :author, class_name: 'Person'

      paginator :offset

      filters :book
      filter :approved, apply: ->(records, value, options) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        if current_user && current_user.book_admin
          records.where(approved_comments(value[0] == 'true'))
        end
      }

      class << self
        def book_comments
          BookComment.arel_table
        end

        def approved_comments(approved = true)
          book_comments[:approved].eq(approved)
        end

        def records(options = {})
          current_user = options[:context][:current_user]
          _model_class.for_user(current_user)
        end
      end
    end
  end
end

module Api
  module V3
    class PostResource < PostResource; end
    class PreferencesResource < PreferencesResource; end
  end
end

module Api
  module V4
    class PostResource < PostResource; end
    class PersonResource < PersonResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource
      has_many :expense_entries, exclude_links: :default
    end

    class BookResource < Api::V2::BookResource
      paginator :paged
    end

    class BookCommentResource < Api::V2::BookCommentResource
      paginator :paged
    end
  end
end

module Api
  module V5
    class PostResource < JSONAPI::Resource
      attribute :title
      attribute :body

      has_one :author, class_name: 'Person', exclude_links: [:self, "related"]
      has_one :section, exclude_links: [:self, :related]
      has_many :tags, acts_as_set: true, inverse_relationship: :posts, eager_load_on_include: false, exclude_links: :default
      has_many :comments, acts_as_set: false, inverse_relationship: :post, exclude_links: ["self", :related]
    end

    class AuthorResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      relationship :posts, to: :many
      relationship :author_detail, to: :one, foreign_key_on: :related

      filter :name

      def self.find_records(filters, options = {})
        rel = _model_class
        filters.each do |attr, filter|
          if attr.to_s == "id"
            rel = rel.where(id: filter)
          else
            rel = rel.where("\"#{attr}\" LIKE \"%#{filter[0]}%\"")
          end
        end
        rel
      end

      def fetchable_fields
        super - [:email]
      end
    end

    class AuthorDetailResource < JSONAPI::Resource
      attributes :author_stuff
    end

    class PaintingResource < JSONAPI::Resource
      model_name 'Painting'
      attributes :title, :category, :collector_roster
      has_one :painter
      has_many :collectors

      filter :title
      filter :category

      def collector_roster
        collectors.map(&:name)
      end
    end

    class CollectorResource < JSONAPI::Resource
      attributes :name
      has_one :painting

      filter :name
      filter :'painting.title_equals', apply: -> (records, values, _opts) do
        records.joins(:painting).where(paintings: { title: values })
      end
    end

    class PainterResource < JSONAPI::Resource
      model_name 'Painter'
      attributes :name
      has_many :paintings

      filter :name, apply: lambda { |records, value, options|
        records.where('name LIKE ?', value)
      }

      def records_for(relation_name)
        records = super(relation_name)

        return records unless relation_name == :paintings
        records.includes(:collectors)
      end
    end

    class PersonResource < JSONAPI::Resource
      attributes :name, :email
      attribute :date_joined, format: :date_with_timezone

      has_many :comments
      has_many :posts
    end

    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class CommentResource < CommentResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end
    class EmployeeResource < EmployeeResource; end
  end
end

module Api
  module V6
    class PersonResource < PersonResource; end
    class TagResource < TagResource; end

    class SectionResource < SectionResource
      has_many :posts
    end

    class CommentResource < CommentResource; end

    class PostResource < PostResource
      # Test caching with SQL fragments
      def self.records(options = {})
        super.joins('INNER JOIN people on people.id = author_id')
      end
    end

    class CustomerResource < JSONAPI::Resource
      attribute :name

      has_many :purchase_orders
    end

    class PurchaseOrderResource < JSONAPI::Resource
      attribute :order_date
      attribute :requested_delivery_date
      attribute :delivery_date
      attribute :delivery_name
      attribute :delivery_address_1
      attribute :delivery_address_2
      attribute :delivery_city
      attribute :delivery_state
      attribute :delivery_postal_code
      attribute :delivery_fee
      attribute :tax
      attribute :total

      has_one :customer
      has_many :line_items, relation_name: -> (options = {}) {
                            context = options[:context]
                            current_user = context ? context[:current_user] : nil

                            unless current_user && current_user.book_admin
                              :line_items
                            else
                              :admin_line_items
                            end
                          },
               reflect: false

      has_many :order_flags, acts_as_set: true,
               relation_name: -> (options = {}) {
                             context = options[:context]
                             current_user = context ? context[:current_user] : nil

                             unless current_user && current_user.book_admin
                               :order_flags
                             else
                               :admin_order_flags
                             end
                           }
    end

    class OrderFlagResource < JSONAPI::Resource
      attributes :name

      has_many :purchase_orders, reflect: false
    end

    class LineItemResource < JSONAPI::Resource
      attribute :part_number
      attribute :quantity
      attribute :item_cost

      has_one :purchase_order
    end
  end

  module V7
    class PurchaseOrderResource < V6::PurchaseOrderResource; end
    class OrderFlagResource < V6::OrderFlagResource; end
    class LineItemResource < V6::LineItemResource; end

    class CustomerResource < V6::CustomerResource
      model_name 'Api::V7::Customer'
    end

    class ClientResource < JSONAPI::Resource
      model_name 'Api::V7::Customer'

      attribute :name

      has_many :purchase_orders
    end

    class CategoryResource < CategoryResource
      attribute :name

      # Raise exception for failure in controller
      def name
        fail "Something Exceptional Happened"
      end
    end
  end

  module V8
    class NumeroTelefoneResource < JSONAPI::Resource
      attribute :numero_telefone
    end
  end

  module V9
    class PersonResource < JSONAPI::Resource
      has_one :preferences
      singleton false
    end

    class PreferencesResource < JSONAPI::Resource
      singleton singleton_key: -> (context) {
        key = context[:current_user].try(:preferences).try(:id)
        raise JSONAPI::Exceptions::RecordNotFound.new(nil) if key.nil?
        key
      }

      has_one :person, :foreign_key_on => :related

      attribute :nickname
    end
  end

end

module AdminApi
  module V1
    class PersonResource < JSONAPI::Resource
    end
  end
end

module DasherizedNamespace
  module V1
    class PersonResource < JSONAPI::Resource
    end
  end
end

module MyEngine
  module Api
    module V1
      class PostResource < PostResource
      end

      class PersonResource < JSONAPI::Resource
        has_many :posts
      end
    end
  end

  module AdminApi
    module V1
      class PostResource < PostResource
      end

      class PersonResource < JSONAPI::Resource
        has_many :posts
      end
    end
  end

  module DasherizedNamespace
    module V1
      class PostResource < PostResource
      end

      class PersonResource < JSONAPI::Resource
        has_many :posts
      end
    end
  end

  module OptionalNamespace
    module V1
      class PostResource < PostResource
      end

      class PersonResource < JSONAPI::Resource
        has_many :posts
      end
    end
  end
end

module ApiV2Engine
  class PostResource < PostResource
    has_one :person
  end

  class PersonResource < JSONAPI::Resource
    has_many :posts
  end
end

module Legacy
  class FlatPost < ActiveRecord::Base
    self.table_name = "posts"
  end
end

class FlatPostResource < JSONAPI::Resource
  model_name "Legacy::FlatPost", add_model_hint: false

  model_hint model: "Legacy::FlatPost", resource: FlatPostResource

  attribute :title
end

class FlatPostsController < JSONAPI::ResourceController
end

# CustomProcessors
class Api::V4::BookProcessor < JSONAPI::Processor
  after_find do
    unless @results.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:total_records] = @result.record_count
      @result.links['spec'] = 'https://test_corp.com'
    end
  end
end

class PostProcessor < JSONAPI::Processor
  def find
    if $PostProcessorRaisesErrors
      raise PostsController::SubSpecialError
    end
    # puts("In custom Operations Processor without Namespace")
    super
  end

  after_find do
    unless @results.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:total_records] = @result.record_count
      @result.links['spec'] = 'https://test_corp.com'
    end
  end
end

module Api
  module V7
    class CategoryProcessor < JSONAPI::Processor
      def show
        if $PostProcessorRaisesErrors
          raise PostsController::SubSpecialError
        end
        # puts("In custom Operations Processor without Namespace")
        super
      end
    end
  end
end

module Api
  module V1
    class PostProcessor < JSONAPI::Processor
      def show
        # puts("In custom Operations Processor with Namespace")
        super
      end
    end
  end
end

module Api
  class BoxResource < JSONAPI::Resource
    has_many :things
  end

  class ThingResource < JSONAPI::Resource
    has_one :box
    has_one :user

    has_many :things
  end

  class UserResource < JSONAPI::Resource
    has_many :things
  end
end

class QuestionResource < JSONAPI::Resource
  has_one :answer
  has_one :respondent, polymorphic: true, class_name: "Respondent", foreign_key_on: :related

  attributes :text
end

class AnswerResource < JSONAPI::Resource
  has_one :question
  has_one :respondent, polymorphic: true
end

class PatientResource < JSONAPI::Resource
  attributes :name
end

class DoctorResource < JSONAPI::Resource
  attributes :name
end

class RespondentResource < JSONAPI::Resource
  abstract
end

class ListResource < JSONAPI::Resource
  has_many :items, class_name: 'ListItem'
end

class ListItemResource < JSONAPI::Resource
  has_one :list
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
