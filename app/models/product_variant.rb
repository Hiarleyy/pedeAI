class ProductVariant < ApplicationRecord
  belongs_to :product

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: :product_id, case_sensitive: false }
  validates :price, numericality: { greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :available, inclusion: { in: [true, false] }
  validates_text_encoding :name
end
