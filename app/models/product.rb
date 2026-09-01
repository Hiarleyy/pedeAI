class Product < ApplicationRecord
  belongs_to :restaurant
  belongs_to :category
  has_many :order_items, dependent: :restrict_with_error

  validates :name, presence: true, length: { in: 2..120 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :price, numericality: { greater_than: 0 }
  validates :available, inclusion: { in: [true, false] }
  validate :category_belongs_to_restaurant

  private

  def category_belongs_to_restaurant
    return if category.nil? || restaurant.nil? || category.restaurant_id == restaurant_id

    errors.add(:category, "deve pertencer ao mesmo restaurante")
  end
end
