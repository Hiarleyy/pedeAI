class Order < ApplicationRecord
  belongs_to :restaurant
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  enum :order_type, { delivery: "delivery", dine_in: "dine_in" }
  enum :status, { pending: "pending", confirmed: "confirmed", preparing: "preparing", ready: "ready", delivered: "delivered", cancelled: "cancelled" }

  validates :customer_name, presence: true, length: { in: 2..120 }
  validates :customer_phone, presence: true, format: { with: /\A[0-9+() .-]{8,20}\z/ }
  validates :order_type, presence: true
  validates :delivery_address, presence: true, if: :delivery?
  validates :table_number, presence: true, if: :dine_in?
  validates :payment_method, inclusion: { in: %w[cash card pix] }
  validates :status, presence: true
  validates_text_encoding :customer_name, :customer_phone, :delivery_address, :table_number
  validate :must_have_items

  before_validation :calculate_total

  def table_label
    dine_in? ? "Mesa #{table_number}" : nil
  end

  private

  def must_have_items
    errors.add(:order_items, "must include at least one item") if order_items.empty?
  end

  def calculate_total
    self.total = order_items.sum { |item| item.quantity.to_i * (item.unit_price || item.product&.price).to_d }
  end
end
