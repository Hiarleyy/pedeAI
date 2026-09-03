class Restaurant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  before_validation :build_slug, on: :create
  validates :name, presence: true, length: { in: 2..120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :menu_description, length: { maximum: 500 }, allow_blank: true
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }

  private

  def build_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end

