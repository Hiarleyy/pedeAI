class Category < ApplicationRecord
  belongs_to :restaurant
  has_many :products, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :restaurant_id }, length: { in: 2..80 }
  validates_text_encoding :name, :description
end
