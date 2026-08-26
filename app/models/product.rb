class Product < ApplicationRecord
  belongs_to :category
  validates :name, presence: true, length: { in: 2..120 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :price, numericality: { greater_than: 0 }
  validates :available, inclusion: { in: [true, false] }
end
