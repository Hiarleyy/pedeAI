class TextEncodingAudit
  Finding = Data.define(:model, :id, :attribute, :paths)

  LEGACY_PRODUCT_NAME = "Suco de Maracuj\u00C3\u00A1".freeze
  LEGACY_PRODUCT_DESCRIPTION = "Suco natural de maracuj\u00C3\u00A1".freeze
  REPAIRED_PRODUCT_NAME = "Suco de Maracuj\u00E1".freeze
  REPAIRED_PRODUCT_DESCRIPTION = "Suco natural de maracuj\u00E1".freeze

  RECORD_CLASSES = [
    Restaurant,
    Category,
    Product,
    ProductAddon,
    ProductVariant,
    User,
    Order,
    OrderItem,
    OrderItemAddon
  ].freeze

  def findings
    RECORD_CLASSES.flat_map do |model|
      model.find_each.filter_map do |record|
        attributes = model.text_encoding_attributes
        paths_by_attribute = attributes.to_h do |attribute|
          [attribute, TextEncodingHealth.suspicious_paths(record.public_send(attribute), attribute.to_s)]
        end.reject { |_attribute, paths| paths.empty? }
        next if paths_by_attribute.empty?

        paths_by_attribute.map { |attribute, paths| Finding.new(model.name, record.id, attribute, paths) }
      end
    end.flatten
  end

  def repair_known!
    repaired = 0
    Product.where(name: LEGACY_PRODUCT_NAME, description: LEGACY_PRODUCT_DESCRIPTION).find_each do |product|
      Product.transaction do
        product.update!(name: REPAIRED_PRODUCT_NAME, description: REPAIRED_PRODUCT_DESCRIPTION)
        repaired += 1
      end
    end
    repaired
  end
end
