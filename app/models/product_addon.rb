class ProductAddon < ApplicationRecord
  belongs_to :product

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: :product_id, case_sensitive: false }
  validates :price, numericality: { greater_than: 0 }
  validates :available, inclusion: { in: [true, false] }
  validates_text_encoding :name
end
