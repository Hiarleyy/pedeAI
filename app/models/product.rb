class Product < ApplicationRecord
  class NestedValidationError < StandardError
    attr_reader :messages

    def initialize(collection, index, record)
      @messages = record.errors.map { |error| "#{collection}[#{index}].#{error.attribute} #{error.message}" }
      super(@messages.join(", "))
    end
  end

  belongs_to :restaurant
  belongs_to :category
  has_many :order_items, dependent: :restrict_with_error
  has_many :addons, class_name: "ProductAddon", dependent: :destroy, inverse_of: :product
  has_many :variants, class_name: "ProductVariant", dependent: :destroy, inverse_of: :product

  validates :name, presence: true, length: { in: 2..120 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :price, numericality: { greater_than: 0 }
  validates :available, inclusion: { in: [true, false] }
  validates_text_encoding :name, :description, :image_url
  validate :category_belongs_to_restaurant

  def replace_addons!(attributes)
    requested_ids = attributes.filter_map { |addon| addon[:id].presence&.to_i }
    addons.where.not(id: requested_ids).destroy_all

    attributes.each_with_index do |addon, index|
      record = addon[:id].present? ? addons.find(addon[:id]) : addons.build
      record.assign_attributes(addon.slice(:name, :price, :available))
      record.save!
    rescue ActiveRecord::RecordInvalid => error
      raise NestedValidationError.new("addons", index, error.record)
    end
  end

  def replace_variants!(attributes)
    requested_ids = attributes.filter_map { |variant| variant[:id].presence&.to_i }
    variants.where.not(id: requested_ids).destroy_all
    attributes.each_with_index do |variant, index|
      record = variant[:id].present? ? variants.find(variant[:id]) : variants.build
      record.assign_attributes(variant.slice(:name, :price, :available, :position))
      record.save!
    rescue ActiveRecord::RecordInvalid => error
      raise NestedValidationError.new("variants", index, error.record)
    end
  end

  private

  def category_belongs_to_restaurant
    return if category.nil? || restaurant.nil? || category.restaurant_id == restaurant_id

    errors.add(:category, "deve pertencer ao mesmo restaurante")
  end
end
