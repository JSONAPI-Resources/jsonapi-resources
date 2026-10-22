require 'active_record'
require 'jsonapi-resources'

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable 'preferences'
  inflect.uncountable 'file_properties'
  inflect.irregular 'numero_telefone', 'numeros_telefone'
end

### DATABASE
ActiveRecord::Schema.define do
  create_table :sessions, id: false, force: true do |t|
    t.string :id, :limit => 36, :primary_key => true, null: false
    t.string :survey_id, :limit => 36, null: false

    t.timestamps
  end

  create_table :responses, force: true do |t|
    #t.string :id, :limit => 36, :primary_key => true, null: false

    t.string :session_id, limit: 36, null: false

    t.string :type
    t.string :question_id, limit: 36

    t.timestamps
  end

  create_table :response_texts, force: true do |t|
    t.text :text
    t.integer :response_id

    t.timestamps
  end

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
    t.string     :title, limit: 255
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
    t.integer :author_id
    t.references :imageable, polymorphic: true, index: true
    t.timestamps null: false
  end

  create_table :documents, force: true do |t|
    t.string  :name
    t.integer :author_id
    t.timestamps null: false
  end

  create_table :products, force: true do |t|
    t.string  :name
    t.integer :designer_id
    t.timestamps null: false
  end

  create_table :file_properties, force: true do |t|
    t.string :name
    t.timestamps null: false
    t.references :fileable, polymorphic: true, index: true
    t.belongs_to :tag, index: true

    t.integer :size
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
    t.references :from, foreign_key: false
    t.references :to, foreign_key: false

    t.timestamps null: false
  end

  create_table :questions, force: true do |t|
    t.string :text
    t.timestamps null: false
  end

  create_table :answers, force: true do |t|
    t.references :question
    t.integer :respondent_id
    t.string  :respondent_type
    t.string :text
    t.timestamps null: false
  end

  create_table :patients, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :doctors, force: true do |t|
    t.string :name
    t.timestamps null: false
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
  create_table :storages, force: true do |t|
    t.string :token, null: false
    t.string :name
    t.timestamps null: false
  end

  create_table :keepers, force: true do |t|
    t.string :name
    t.string :keepable_type, null: false
    t.integer :keepable_id, null: false
    t.timestamps null: false
  end

  create_table :access_cards, force: true do |t|
    t.string :token, null: false
    t.string :security_level
    t.timestamps null: false
  end

  create_table :workers, force: true do |t|
    t.string :name
    t.integer :access_card_id, null: false
    t.timestamps null: false
  end

  create_table :agencies, force: true do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :indicators, force: true do |t|
    t.string :name
    t.string :import_id
    t.integer :agency_id, null: false
    t.timestamps null: false
  end

  create_table :widgets, force: true do |t|
    t.string :name
    t.string :indicator_import_id, null: false
    t.timestamps null: false
  end

  create_table :robots, force: true do |t|
    t.string :name
    t.integer :version
    t.timestamps null: false
  end
end

### MODELS
class Session < ActiveRecord::Base
  self.primary_key = "id"
  has_many :responses
end

class Response < ActiveRecord::Base
	belongs_to :session
	has_one :paragraph, :class_name => "ResponseText::Paragraph"

	def response_type
		case self.type
		when "Response::SingleTextbox"
          "single_textbox"
		else
          "question"
		end
	end
	def response_type=type
		self.type = case type
		when "single_textbox"
          "Response::SingleTextbox"
		else
		  "Response"
		end
	end
end

class Response::SingleTextbox < Response
  has_one :paragraph, :class_name => "ResponseText::Paragraph", :foreign_key => :response_id
end

class ResponseText < ActiveRecord::Base
end

class ResponseText::Paragraph < ResponseText
end

class Person < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id'
  has_many :comments, foreign_key: 'author_id'
  has_many :book_comments, foreign_key: 'author_id'
  has_many :expense_entries, foreign_key: 'employee_id', dependent: :restrict_with_exception
  has_many :vehicles
  belongs_to :preferences
  belongs_to :hair_cut
  has_one :author_detail

  has_and_belongs_to_many :books, join_table: :book_authors
  has_and_belongs_to_many :not_banned_books, -> { merge(Book.not_banned) },
                          class_name: 'Book',
                          join_table: :book_authors

  has_many :even_posts, -> { where('posts.id % 2 = 0') }, class_name: 'Post', foreign_key: 'author_id'
  has_many :odd_posts, -> { where('posts.id % 2 = 1') }, class_name: 'Post', foreign_key: 'author_id'

  has_many :pictures, foreign_key: 'author_id'

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
  belongs_to :parent_post, class_name: 'Post', foreign_key: 'parent_post_id'

  validates :author, presence: true
  validates :title, length: { maximum: 35 }

  before_destroy :destroy_callback

  def destroy_callback
    case title
    when "can't destroy me", "can't destroy me either"
      errors.add(:base, "can't destroy me")
      throw(:abort)
    when "locked title"
      errors.add(:title, "is locked")
      throw(:abort)
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

  has_and_belongs_to_many :comments, join_table: :comments_tags
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
  has_many :expense_entries, foreign_key: 'currency_code'
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
      throw(:abort)
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
  include ActiveModel::Model

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

  validates :name, presence: true
end

class Book < ActiveRecord::Base
  has_many :book_comments, -> { order(:id) }
  has_many :approved_book_comments, -> { where(approved: true).order(:id) }, class_name: "BookComment"

  has_and_belongs_to_many :authors, join_table: :book_authors, class_name: "Person"

  scope :not_banned, -> {
    where(banned: false)
  }
end

class BookComment < ActiveRecord::Base
  default_scope { order(:id) }

  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  belongs_to :book

  def self.for_user(current_user)
    records = self.all
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
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'

  belongs_to :imageable, polymorphic: true
  belongs_to :document, -> { where( pictures: { imageable_type: 'Document' } ) }, foreign_key: 'imageable_id'
  belongs_to :product, -> { where( pictures: { imageable_type: 'Product' } ) }, foreign_key: 'imageable_id'

  has_one :file_properties, as: 'fileable'
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
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'
  has_one :file_properties, as: 'fileable'
end

class Product < ActiveRecord::Base
  has_many :pictures, as: :imageable
  belongs_to :designer, class_name: 'Person', foreign_key: 'designer_id'
  has_one :file_properties, as: 'fileable'
end

class FileProperties < ActiveRecord::Base
  belongs_to :fileable, polymorphic: true
  belongs_to :tag
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

class Storage < ActiveRecord::Base
  has_one :keeper, class_name: 'Keeper', as: :keepable
end

class Keeper < ActiveRecord::Base
  belongs_to :keepable, polymorphic: true
end

class AccessCard < ActiveRecord::Base
  has_many :workers
end

class Worker < ActiveRecord::Base
  belongs_to :access_card
end

class Agency < ActiveRecord::Base
end

class Indicator < ActiveRecord::Base
  belongs_to :agency
  has_many :widgets, primary_key: :import_id, foreign_key: :indicator_import_id
end

class Widget < ActiveRecord::Base
  belongs_to :indicator, primary_key: :import_id, foreign_key: :indicator_import_id
end

class Robot < ActiveRecord::Base
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
class SessionsController < ActionController::Base
  include JSONAPI::ActsAsResourceController
  before_action :create_responses_relationships, :only => [:create,:update]

  private
    def create_responses_relationships
      if !params[:data][:relationships].nil? && !params[:data][:relationships][:responses].nil?
        responses_params = params[:data][:relationships].delete(:responses)
        params[:data][:attributes][:responses] = responses_params
      end
    end
end

class AuthorsController < JSONAPI::ResourceControllerMetal
  include Rails.application.routes.url_helpers
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

  # This is used to test that classes that are allowed are reraised by
  # the operations dispatcher.
  rescue_from PostsController::SpecialError do
    head :forbidden
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

class FilePropertiesController < JSONAPI::ResourceController
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
      def context
        {current_user: $test_user}
      end
    end

    class PeopleController < JSONAPI::ResourceController
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
    class MoonsController < JSONAPI::ResourceController
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
  end

  module V6
    class AuthorsController < JSONAPI::ResourceController
    end

    class AuthorDetailsController < JSONAPI::ResourceController
    end

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
    class AuthorsController < JSONAPI::ResourceController
    end

    class AuthorDetailsController < JSONAPI::ResourceController
    end

    class PostsController < JSONAPI::ResourceController
    end

    class CommentsController < JSONAPI::ResourceController
    end

    class SectionsController < JSONAPI::ResourceController
    end

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

class StoragesController < BaseController
end

class KeepersController < BaseController
end

class AccessCardsController < BaseController
end

class WorkersController < BaseController
end

class WidgetsController < JSONAPI::ResourceController
end

class IndicatorsController < JSONAPI::ResourceController
end

class RobotsController < JSONAPI::ResourceController
end

### RESOURCES
class BaseResource < JSONAPI::Resource
  abstract
end

class SessionResource < JSONAPI::Resource
  key_type :uuid

  attributes :survey_id, :responses

  has_many :responses

  def responses=params
    params[:data].each { |datum|
      response = @model.responses.build(((datum[:attributes].respond_to?(:permit))? datum[:attributes].permit(:response_type, :question_id) : datum[:attributes]))

      (datum[:relationships] || {}).each_pair { |k,v|
        case k
        when "paragraph"
          response.paragraph = ResponseText::Paragraph.create(((v[:data][:attributes].respond_to?(:permit))? v[:data][:attributes].permit(:text) : v[:data][:attributes]))
        end
      }
    }
  end
  def responses
  end

  def self.creatable_fields(context)
    super + [
      :id,
    ]
  end

  def fetchable_fields
    super - [:responses]
  end
end

class ResponseResource < JSONAPI::Resource
  model_hint model: Response::SingleTextbox, resource: :response

  has_one :session

  attributes :question_id, :response_type

  has_one :paragraph
end

class ParagraphResource < JSONAPI::Resource
  model_name 'ResponseText::Paragraph'

  attributes :text

  has_one :response
end

class PersonResource < BaseResource
  attributes :name, :email
  attribute :date_joined, format: :date_with_timezone

  has_many :comments, inverse_relationship: :author
  has_many :posts, inverse_relationship: :author
  has_many :vehicles, polymorphic: true

  has_one :preferences
  has_one :hair_cut

  has_many :expense_entries

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

class PersonWithEvenAndOddPostsResource < JSONAPI::Resource
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
  has_many :comments
  # Not including the planets relationship so they don't get output
  #has_many :planets
end

class SectionResource < JSONAPI::Resource
  attributes 'name'

  has_many :posts
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
           records.where('posts.id IN (?)', value)
         }

  filter :search,
    verify: ->(values, context) {
      values.all?{|v| (v.is_a?(Hash) || v.is_a?(ActionController::Parameters)) } && values
    },
    apply: -> (records, values, _options) {
      records.where(title: values.first['title'])
    }

  filter 'tags.name'

  filter 'comments.author.name'
  filter 'comments.tags.name'

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
  attribute :id, format: :id, readonly: false

  has_many :expense_entries

  filter :country_name

  key_type :string
end

class ExpenseEntryResource < JSONAPI::Resource
  attributes :cost
  attribute :transaction_date, format: :date

  has_one :iso_currency, foreign_key: 'currency_code'
  has_one :employee
end

class EmployeeResource < JSONAPI::Resource
  attributes :name, :email
  model_name 'Person'
  has_many :expense_entries
end

class PoroResource < JSONAPI::BasicResource
  root_resource

  class << self
    def find_records(filters, options)
      fail NotImplementedError, <<~EOF
        Should be something like
        def find_records(filters, options)
          breeds = []
          id_filter = filters[:id]
          id_filter = [id_filter] unless id_filter.nil? || id_filter.is_a?(Array)
          $breed_data.breeds.values.each do |breed|
            breeds.push(breed) unless id_filter && !id_filter.include?(breed.id)
          end
          breeds
        end
      EOF
    end

    def find_record_by_key(key, options = {})
      fail NotImplementedError, <<~EOF
        Should be something like
        def find_record_by_key(key, options = {})
          $breed_data.breeds[key.to_i]
        end
      EOF
    end

    def find_records_by_keys(keys, options = {})
      fail NotImplementedError, <<~EOF
        Should be something like
        def find_records_by_keys(keys, options = {})
          breeds = []
          keys.each do |key|
            breeds.push($breed_data.breeds[key.to_i])
          end
          breeds
        end
      EOF
    end

    # Finds Resources using the `filters`. Pagination and sort options are used when provided
    #
    # @param filters [Hash] the filters hash
    # @option options [Hash] :context The context of the request, set in the controller
    # @option options [Hash] :sort_criteria The `sort criteria`
    # @option options [Hash] :include_directives The `include_directives`
    #
    # @return [Array<Resource>] the Resource instances matching the filters, sorting and pagination rules.
    def find(filters, options = {})
      records = find_records(filters, options)
      resources_for(records, options[:context])
    end

    # Records
    def find_fragments(filters, options)
      fragments = {}
      find_records(filters, options).each do |record|
        rid = JSONAPI::ResourceIdentity.new(resource_klass, record.id)
        # We can use either the id or the full resource.
        # fragments[rid] = JSONAPI::ResourceFragment.new(rid)
        #  OR
        # fragments[rid] = JSONAPI::ResourceFragment.new(rid, resource: resource_klass.new(record, options[:context]))
        # In this case we will use the resource since we already looked up the model instance
        fragments[rid] = JSONAPI::ResourceFragment.new(rid, resource: resource_klass.new(record, options[:context]))
      end
      fragments
    end

    def resource_klass
      self
    end

    # Counts Resources found using the `filters`
    #
    # @param filters [Hash] the filters hash
    # @option options [Hash] :context The context of the request, set in the controller
    #
    # @return [Integer] the count
    def count(filters, options = {})
      fail NotImplementedError, <<~EOF
        Should be something like
        def count(filters, options)
          0
        end
      EOF
    end

    # Returns the single Resource identified by `key`
    #
    # @param key the primary key of the resource to find
    # @option options [Hash] :context The context of the request, set in the controller
    def find_by_key(key, options = {})
      record = find_record_by_key(key, options)
      resource_for(record, options[:context])
    end

    def find_to_populate_by_keys(keys, options = {})
      find_by_keys(keys, options)
    end

    # Returns an array of Resources identified by the `keys` array
    #
    # @param keys [Array<key>] Array of primary keys to find resources for
    # @option options [Hash] :context The context of the request, set in the controller
    def find_by_keys(keys, options = {})
      records = find_records_by_keys(keys, options)
      resources_for(records, options[:context])
    end
  end
end

class BreedResource < PoroResource

  attribute :name, format: :title

  # This is unneeded, just here for testing
  routing_options param: :id

  class << self
    def find_records(filters, options = {})
      breeds = []
      id_filter = filters[:id]
      id_filter = [id_filter] unless id_filter.nil? || id_filter.is_a?(Array)
      $breed_data.breeds.values.each do |breed|
        breeds.push(breed) unless id_filter && !id_filter.include?(breed.id)
      end
      breeds
    end

    def find_record_by_key(key, options = {})
      $breed_data.breeds[key.to_i]
    end

    def find_records_by_keys(keys, options = {})
      breeds = []
      keys.each do |key|
        breeds.push($breed_data.breeds[key.to_i])
      end
      breeds
    end
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
  belongs_to :planet_type

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
    records.where(concat_table_field(options.dig(:_relation_helper_options, :join_manager).source_join_details[:alias], :description) => value)
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

  has_one :author, :foreign_key_on => :related, class_name: "Person"
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
  has_one :author

  has_one :imageable, polymorphic: true
  has_one :file_properties, inverse_relationship: :fileable, :foreign_key_on => :related, polymorphic: true

  filter 'imageable.name', perform_joins: true, apply: -> (records, value, options) {
    join_manager = options.dig(:_relation_helper_options, :join_manager)
    relationship = _relationship(:imageable)
    or_parts = relationship.resource_types.collect do |type|
      table_alias = join_manager.join_details_by_polymorphic_relationship(relationship, type)[:alias]
      "#{concat_table_field(table_alias, "name")} = '#{value.first}'"
    end
    records.where(Arel.sql(or_parts.join(' OR ')))
  }

  filter 'imageable#documents.name'
end

class ImageableResource < JSONAPI::Resource
  polymorphic
end

class FileableResource < JSONAPI::Resource
  polymorphic
end

class DocumentResource < JSONAPI::Resource
  attribute :name
  has_many :pictures, inverse_relationship: :imageable
  has_one :author, class_name: 'Person'

  has_one :file_properties, inverse_relationship: :fileable, :foreign_key_on => :related
end

class ProductResource < JSONAPI::Resource
  attribute :name
  has_many :pictures, inverse_relationship: :imageable
  has_one :designer, class_name: 'Person'

  has_one :file_properties, inverse_relationship: :fileable, :foreign_key_on => :related

  def picture_id
    _model.picture.id
  end
end

class FilePropertiesResource < JSONAPI::Resource
  attribute :name
  attribute :size

  has_one :fileable, polymorphic: true
  has_one :tag
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

  has_many :books, inverse_relationship: :authors
  has_many :pictures
  # has_one :preferences
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
    class SectionResource < SectionResource; end
    class TagResource < TagResource; end
    class CommentResource < CommentResource; end
    class VehicleResource < VehicleResource; end
    class CarResource < CarResource; end
    class BoatResource < BoatResource; end
    class HairCutResource < HairCutResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end

    class PersonResource < PersonResource
      has_many :book_comments
    end

    class PostResource < PostResource; end

    class AuthorResource < JSONAPI::Resource
      model_name 'Person'
      attributes :name

      has_many :books, inverse_relationship: :authors, relation_name: -> (options) {
        book_admin = options[:context][:book_admin] || options[:context][:current_user].try(:book_admin)

        if book_admin
          :books
        else
          :not_banned_books
        end
      }

      has_many :book_comments
    end

    class BookResource < JSONAPI::Resource
      attribute "title"
      attributes :isbn, :banned

      has_many "authors", class_name: 'Authors'

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

      filter :book_comments,
              apply: ->(records, value, options) {
                context = options[:context]
                current_user = context ? context[:current_user] : nil

                relation =
                unless current_user && current_user.book_admin
                  :approved_book_comments
                else
                  :book_comments
                end

                # Using an inner join here, which is different than the new default left_join
                return records.joins(relation).references(relation).where('book_comments.id' => value)
              }

      filter :banned, apply: :apply_filter_banned

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

          records = _model_class.all
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
          end
        end

      end
    end

    class BookCommentResource < JSONAPI::Resource
      attributes :body, :approved

      has_one :book
      has_one :author

      filters :book
      filter :approved, apply: ->(records, value, options) {
        context = options[:context]
        current_user = context ? context[:current_user] : nil

        if current_user && current_user.book_admin
          records.where(approved_comments(value[0] == 'true'))
        end
      }
      filter :body, apply: ->(records, value, options) {
        records.where(BookComment.arel_table[:body].matches("%#{value[0]}%"))
      }

      # Add default sort to ensure stable ordering across cache/non-cache scenarios
      def self.default_sort
        [{field: 'id', direction: :asc}]
      end

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
    class PlanetResource < JSONAPI::Resource
    end
    class MoonResource < JSONAPI::Resource
      has_one :planet, always_include_optional_linkage_data: true

      def self.records(options = {})
        Moon.joins(:planet).merge(Planet.where(name: 'Satern')) # sic
      end
    end
  end
end

module Api
  module V4
    class PostResource < PostResource
      class << self
        def records(options = {})
          # Sets up a performance issue for testing
          super(options).joins(:comments)
        end
      end
    end

    class PersonResource < PersonResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource
      has_many :expense_entries, exclude_links: :default
    end

    class AuthorResource < Api::V2::AuthorResource; end

    class BookResource < Api::V2::BookResource
      paginator :paged
    end

    class BiggerBookResource < Api::V4::BookResource
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

      filter :name, apply: lambda { |records, value, options|
        table_alias = options.dig(:_relation_helper_options, :join_manager).source_join_details[:alias]
        t = Arel::Table.new(:people, as: table_alias)
        records.where(t[:name].matches("%#{value[0]}%"))
      }

      def fetchable_fields
        super - [:email]
      end

      def self.sortable_fields(context)
        super(context) + [:"author_detail.author_stuff"]
      end
    end

    class AuthorDetailResource < JSONAPI::Resource
      attributes :author_stuff
    end

    class PaintingResource < JSONAPI::Resource
      model_name 'Painting'
      attributes :title, :category #, :collector_roster
      has_one :painter
      has_many :collectors

      filter :title
      filter :category
      filter :collectors

      def collector_roster
        collectors.map(&:name)
      end
    end

    class CollectorResource < JSONAPI::Resource
      attributes :name
      has_one :painting
    end

    class PainterResource < JSONAPI::Resource
      model_name 'Painter'
      attributes :name
      has_many :paintings

      filter :name, apply: lambda { |records, value, options|
        records.where('name LIKE ?', value)
      }
    end

    class PersonResource < PersonResource; end
    class PreferencesResource < PreferencesResource; end
    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class CommentResource < CommentResource; end
    class ExpenseEntryResource < ExpenseEntryResource; end
    class IsoCurrencyResource < IsoCurrencyResource; end
    class EmployeeResource < EmployeeResource; end
    class VehicleResource < PersonResource; end
    class HairCutResource < HairCutResource; end
  end
end

module Api
  module V6
    class HairCutResource < HairCutResource; end

    class AuthorDetailResource < JSONAPI::Resource
      attributes :author_stuff
      has_one :author, foreign_key: :person_id, inverse_relationship: :author_detail
    end

    class AuthorResource < JSONAPI::Resource
      attributes :name, :email
      model_name 'Person'
      relationship :posts, to: :many
      relationship :author_detail, to: :one, foreign_key_on: :related, foreign_key: :person_id
      has_one :hair_cut

      filter :name

      def self.sortable_fields(context)
        super(context) + [:"author_detail.author_stuff"]
      end
    end

    class PreferencesResource < PreferencesResource; end
    class PersonResource < PersonResource; end
    class TagResource < TagResource; end

    class SectionResource < SectionResource
      has_many :posts
    end

    class CommentResource < CommentResource; end

    class PostResource < PostResource
      attribute :base

      has_one :author

      def base
        _model.title
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

      caching false

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

    class PostResource < PostResource
      has_many :comments, apply_join: -> (records, relationship, resource_type, join_type, options) {
        case join_type
          when :inner
            records = records.joins(relationship.relation_name(options))
          when :left
            records = records.joins_left(relationship.relation_name(options))
        end
        records.where(comments: {approved: true})
      }
    end

    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class CommentResource < CommentResource
      has_one :author, class_name: 'Person', apply_join: -> (records, relationship, resource_type, join_type, options) {
        records = apply_join(records: records,
                             relationship: relationship,
                             resource_type: resource_type,
                             join_type: join_type,
                             options: options)

        records.where(author: {special: true})
      }
    end

    class AuthorResource < Api::V2::AuthorResource
    end

    class BookResource < Api::V2::BookResource
    end

    class BookCommentResource < Api::V2::BookCommentResource
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

  module V10
    class PersonResource < PersonResource; end
    class PostResource < PostResource
      has_many :comments, apply_join: -> (records, relationship, resource_type, join_type, options) {
        case join_type
        when :inner
          records = records.joins(relationship.relation_name(options))
        when :left
          records = records.joins_left(relationship.relation_name(options))
        end
        records.where(comments: {approved: true})
      }
    end

    class TagResource < TagResource; end
    class SectionResource < SectionResource; end
    class CommentResource < CommentResource
      has_one :author, class_name: 'Person', apply_join: -> (records, relationship, resource_type, join_type, options) {
        records = apply_join(records: records,
                             relationship: relationship,
                             resource_type: resource_type,
                             join_type: join_type,
                             options: options)

        records.where(author: {special: true})
      }
    end

    class AuthorResource < Api::V2::AuthorResource
    end

    class BookResource < Api::V2::BookResource
    end

    class BookCommentResource < Api::V2::BookCommentResource
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

module OptionalNamespace
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

class BlogPost < ActiveRecord::Base
  self.table_name = 'posts'
end

class BlogPostsController < JSONAPI::ResourceController

end

class BlogPostResource < JSONAPI::Resource
  model_name 'BlogPost', add_model_hint: false
  model_hint model: 'BlogPost', resource: BlogPostResource

  attribute :name, :delegate => :title
  attribute :body

  filter :name
end

class AgencyResource < JSONAPI::Resource
  attributes :name
end

class IndicatorResource < JSONAPI::Resource
  attributes :name
  has_one :agency
  has_many :widgets, foreign_key: :indicator_import_id, primary_key: :import_id

  def self.sortable_fields(_context = nil)
    super + [:'widgets.name']
  end
end

class WidgetResource < JSONAPI::Resource
  attributes :name
  has_one :indicator, foreign_key: :indicator_import_id, primary_key: :import_id

  def self.sortable_fields(_context = nil)
    super + [:'indicator.agency.name']
  end
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

    filter 'things.things.name'
    filter 'things.name'
  end

  class ThingResource < JSONAPI::Resource
    has_one :box
    has_one :user

    has_many :things

    filter 'things.things.name'
  end

  class UserResource < JSONAPI::Resource
    has_many :things
    attribute :name
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

class StorageResource < JSONAPI::Resource
  key_type :string
  primary_key :token

  attribute :name
  has_many :keepers
end

class KeeperResource < JSONAPI::Resource
  has_one :keepable, polymorphic: true

  attribute :name
end

class KeepableResource < JSONAPI::Resource
  has_many :keepers
end

class AccessCardResource < JSONAPI::Resource
  key_type :string
  primary_key :token

  has_many :workers

  attribute :security_level
end

class WorkerResource < JSONAPI::Resource
  has_one :access_card

  attribute :name
end

class RobotResource < ::JSONAPI::Resource
  attribute :name
  attribute :version, sortable: false

  sort :lower_name, apply: ->(records, direction, _context) do
    records.order("LOWER(robots.name) #{direction}")
  end
end

### PORO Data - don't do this in a production app
$breed_data = BreedData.new
$breed_data.add(Breed.new(0, 'persian'))
$breed_data.add(Breed.new(1, 'siamese'))
$breed_data.add(Breed.new(2, 'sphinx'))
$breed_data.add(Breed.new(3, 'to_delete'))
