class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { in: 2..80 }
end
