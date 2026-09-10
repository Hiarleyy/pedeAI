class OrderItemAddon < ApplicationRecord
  belongs_to :order_item

  validates :name, presence: true, length: { maximum: 120 }
  validates :price, numericality: { greater_than: 0 }
  validates_text_encoding :name
end
