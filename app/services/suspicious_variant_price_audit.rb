class SuspiciousVariantPriceAudit
  DEFAULT_EXCLUDED_SLUGS = ["burger-lab"].freeze

  def self.call(excluded_restaurant_slugs: DEFAULT_EXCLUDED_SLUGS)
    ProductVariant.joins(product: :restaurant)
      .where("product_variants.price < products.price")
      .where.not(restaurants: { slug: excluded_restaurant_slugs })
      .order("restaurants.slug", "products.name", "product_variants.position")
  end
end
