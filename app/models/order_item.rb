class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  has_many :addons, class_name: "OrderItemAddon", dependent: :destroy, inverse_of: :order_item
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 50 }
  validates :unit_price, numericality: { greater_than: 0 }
  validates :note, length: { maximum: 500 }, allow_blank: true
  validates_text_encoding :note, :variant_name
  before_validation :copy_product_price, on: :create
  private
  def copy_product_price
    self.unit_price ||= product&.price
  end
end
