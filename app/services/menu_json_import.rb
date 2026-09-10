require "json"
require "set"

class MenuJsonImport
  MAX_FILE_SIZE = 1.megabyte
  MAX_CATEGORIES = 200
  MAX_PRODUCTS = 2_000

  Result = Data.define(:categories_created, :products_created, :errors) do
    def success? = errors.empty?
  end

  def initialize(restaurant, content)
    @restaurant = restaurant
    @content = content
    @errors = []
  end

  def call
    payload = parse_payload
    return failure if payload.nil?

    categories = validate_payload(payload)
    return failure unless @errors.empty?

    persist(categories)
  rescue ActiveRecord::RecordInvalid => error
    @errors << error.record.errors.full_messages.join(", ")
    failure
  end

  private

  def parse_payload
    JSON.parse(@content)
  rescue JSON::ParserError
    @errors << "Arquivo JSON inválido"
    nil
  end

  def validate_payload(payload)
    return [] unless validate_object(payload, "root", %w[version categories])
    validate_value(payload["version"], "version", :integer, required: true)
    add_error("version deve ser 1") unless payload["version"] == 1
    categories = payload["categories"]
    unless categories.is_a?(Array) && categories.any? && categories.length <= MAX_CATEGORIES
      add_error("categories deve conter entre 1 e #{MAX_CATEGORIES} categorias")
      return []
    end

    seen_categories = Set.new
    seen_products = Set.new
    products_count = 0
    categories.each_with_index.map do |category, category_index|
      path = "categories[#{category_index}]"
      next { attributes: {}, products: [] } unless validate_object(category, path, %w[name description position products])
      name = validate_name(category["name"], "#{path}.name", 2, 80)
      normalized_name = normalize(name)
      add_error("#{path}.name está duplicado") if normalized_name && !seen_categories.add?(normalized_name)
      validate_optional_string(category["description"], "#{path}.description", 500)
      validate_optional_integer(category["position"], "#{path}.position", minimum: 0)

      products = category.key?("products") ? category["products"] : []
      unless products.is_a?(Array)
        add_error("#{path}.products deve ser uma lista")
        products = []
      end

      product_data = products.each_with_index.map do |product, product_index|
        products_count += 1
        validate_product(product, "#{path}.products[#{product_index}]", seen_products)
      end
      { attributes: category.slice("name", "description", "position"), products: product_data }
    end.tap do
      add_error("O arquivo excede o limite de #{MAX_PRODUCTS} produtos") if products_count > MAX_PRODUCTS
      existing_names = @restaurant.products.pluck(:name).map { |name| normalize(name) }.to_set
      seen_products.each { |name| add_error("Já existe um produto com o nome #{name.inspect}") if existing_names.include?(name) }
    end
  end

  def validate_product(product, path, seen_products)
    return { attributes: {}, addons: [], variants: [] } unless validate_object(product, path, %w[name description price available addons variants])
    name = validate_name(product["name"], "#{path}.name", 2, 120)
    normalized_name = normalize(name)
    add_error("#{path}.name está duplicado") if normalized_name && !seen_products.add?(normalized_name)
    validate_optional_string(product["description"], "#{path}.description", 500)
    validate_price(product["price"], "#{path}.price")
    validate_optional_boolean(product["available"], "#{path}.available")

    {
      attributes: product.slice("name", "description", "price", "available"),
      addons: validate_options(product["addons"], "#{path}.addons", variant: false),
      variants: validate_options(product["variants"], "#{path}.variants", variant: true)
    }
  end

  def validate_options(options, path, variant:)
    return [] if options.nil?
    unless options.is_a?(Array)
      add_error("#{path} deve ser uma lista")
      return []
    end

    seen_names = Set.new
    options.each_with_index.map do |option, index|
      item_path = "#{path}[#{index}]"
      allowed = variant ? %w[name price available position] : %w[name price available]
      next {} unless validate_object(option, item_path, allowed)
      name = validate_name(option["name"], "#{item_path}.name", 1, 120)
      normalized_name = normalize(name)
      add_error("#{item_path}.name está duplicado") if normalized_name && !seen_names.add?(normalized_name)
      validate_price(option["price"], "#{item_path}.price")
      validate_optional_boolean(option["available"], "#{item_path}.available")
      validate_optional_integer(option["position"], "#{item_path}.position", minimum: 0) if variant
      option.slice(*allowed)
    end
  end

  def persist(categories)
    categories_created = 0
    products_created = 0
    Category.transaction do
      categories.each do |entry|
        attributes = compact_attributes(entry[:attributes])
        category = @restaurant.categories.where("LOWER(name) = ?", normalize(attributes.fetch("name"))).first
        unless category
          category = @restaurant.categories.create!(attributes)
          categories_created += 1
        end
        entry[:products].each do |product_entry|
          product = @restaurant.products.create!(compact_attributes(product_entry[:attributes], default_available: true).merge(category: category, image_url: nil))
          product_entry[:addons].each { |addon| product.addons.create!(compact_attributes(addon, default_available: true)) }
          product_entry[:variants].each_with_index do |variant, index|
            product.variants.create!(compact_attributes(variant, default_available: true).merge("position" => variant.fetch("position", index)))
          end
          products_created += 1
        end
      end
    end
    Result.new(categories_created, products_created, [])
  end

  def validate_object(value, path, allowed)
    unless value.is_a?(Hash)
      add_error("#{path} deve ser um objeto")
      return false
    end
    (value.keys - allowed).each { |key| add_error("#{path}.#{key} não é aceito") }
    true
  end

  def validate_name(value, path, minimum, maximum)
    validate_value(value, path, :string, required: true)
    return unless value.is_a?(String)

    add_error("#{path} deve ter entre #{minimum} e #{maximum} caracteres") unless value.strip.length.between?(minimum, maximum)
    value
  end

  def validate_price(value, path)
    validate_value(value, path, :number, required: true)
    add_error("#{path} deve ser maior que zero") unless value.is_a?(Numeric) && value.positive?
  end

  def validate_optional_string(value, path, maximum)
    return if value.nil?
    validate_value(value, path, :string)
    add_error("#{path} deve ter no máximo #{maximum} caracteres") if value.is_a?(String) && value.length > maximum
  end

  def validate_optional_boolean(value, path)
    return if value.nil?
    validate_value(value, path, :boolean)
  end

  def validate_optional_integer(value, path, minimum:)
    return if value.nil?
    validate_value(value, path, :integer)
    add_error("#{path} deve ser maior ou igual a #{minimum}") if value.is_a?(Integer) && value < minimum
  end

  def validate_value(value, path, type, required: false)
    if value.nil?
      add_error("#{path} é obrigatório") if required
      return
    end
    valid = case type
    when :string then value.is_a?(String)
    when :number then value.is_a?(Numeric)
    when :integer then value.is_a?(Integer)
    when :boolean then value == true || value == false
    end
    add_error("#{path} possui tipo inválido") unless valid
  end

  def compact_attributes(attributes, default_available: false)
    attributes.compact.transform_values { |value| value.is_a?(String) ? value.strip : value }.tap do |values|
      values["available"] = true if default_available && !values.key?("available")
    end
  end

  def normalize(value) = value.to_s.strip.downcase
  def add_error(message) = @errors << message
  def failure = Result.new(0, 0, @errors)
end
