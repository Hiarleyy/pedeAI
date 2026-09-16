class OrderItemPrice
  def self.calculate(product:, variant: nil, addons: [])
    base_price = variant ? variant.price : product.price
    base_price.to_d + addons.sum { |addon| addon.price.to_d }
  end
end
