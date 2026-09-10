require "test_helper"

class Api::V1::AdminCrudControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Admin")
    @owner = User.create!(restaurant: @restaurant, name: "Dono", email: "dono-admin@example.com", password: "secret123", role: "superAdmin")
    @category = Category.create!(restaurant: @restaurant, name: "Bebidas")
    @product = Product.create!(restaurant: @restaurant, category: @category, name: "Suco", price: 12.0, available: false)
  end

  test "CRUD de categoria funciona pela rota com slug" do
    post categories_path, params: { category: { name: "Sobremesas", description: "Doces", position: 2 } }, headers: auth, as: :json
    assert_response :created
    category_id = response.parsed_body["id"]

    patch "#{categories_path}/#{category_id}", params: { category: { name: "Doces", description: "Sobremesas", position: 3 } }, headers: auth, as: :json
    assert_response :success
    assert_equal "Doces", response.parsed_body["name"]

    get "#{categories_path}/#{category_id}", as: :json
    assert_response :success

    delete "#{categories_path}/#{category_id}", headers: auth, as: :json
    assert_response :no_content
    assert_not Category.exists?(category_id)
  end

  test "listagem administrativa inclui produtos indisponíveis e permite atualizar" do
    get "#{products_path}?admin=true", headers: auth, as: :json
    assert_response :success
    assert_includes response.parsed_body.pluck("id"), @product.id

    patch "#{products_path}/#{@product.id}", params: { product: { available: true, name: "Suco Natural", category_id: @category.id, price: 13.0 } }, headers: auth, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["available"]
    assert_equal "Suco Natural", @product.reload.name
  end

  test "produto não aceita categoria de outro restaurante" do
    other_restaurant = Restaurant.create!(name: "Outro Restaurante")
    other_category = Category.create!(restaurant: other_restaurant, name: "Bebidas")

    patch "#{products_path}/#{@product.id}", params: { product: { category_id: other_category.id } }, headers: auth, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["messages"].join, "mesmo restaurante"
  end

  test "mesmo nome de categoria é permitido em restaurantes diferentes" do
    other_restaurant = Restaurant.create!(name: "Outro Restaurante")

    assert_difference "Category.count", 1 do
      Category.create!(restaurant: other_restaurant, name: @category.name)
    end
  end

  test "produto vinculado a pedido retorna erro de validação ao excluir" do
    order = Order.new(restaurant: @restaurant, customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix")
    order.order_items.build(product: @product, quantity: 1, unit_price: @product.price)
    order.save!

    delete "#{products_path}/#{@product.id}", headers: auth, as: :json

    assert_response :unprocessable_entity
    assert Product.exists?(@product.id)
  end

  test "rota com slug não expõe registro de outro restaurante" do
    other_restaurant = Restaurant.create!(name: "Outro Restaurante")
    other_category = Category.create!(restaurant: other_restaurant, name: "Massas")
    other_product = Product.create!(restaurant: other_restaurant, category: other_category, name: "Lasanha", price: 30)

    get "#{categories_path}/#{other_category.id}", as: :json
    assert_response :not_found
    get "#{products_path}/#{other_product.id}", as: :json
    assert_response :not_found
  end

  test "permite atualizar font_family com opcao valida e rejeita invalida" do
    patch restaurant_path, params: { restaurant: { font_family: "poppins" } }, headers: auth, as: :json
    assert_response :success
    assert_equal "poppins", response.parsed_body["font_family"]
    assert_equal "poppins", @restaurant.reload.font_family

    patch restaurant_path, params: { restaurant: { font_family: "comic-sans" } }, headers: auth, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["messages"].join, "Font family"
  end

  test "administrador configura adicionais e catálogo público expõe apenas ativos" do
    patch "#{products_path}/#{@product.id}", params: { product: {
      addons: [
        { name: "Leite em pó", price: 2.5, available: true },
        { name: "Chantilly", price: 3, available: false }
      ]
    } }, headers: auth, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body.fetch("addons").length

    @product.update!(available: true)
    get products_path, as: :json

    assert_response :success
    product = response.parsed_body.find { |item| item["id"] == @product.id }
    assert_equal ["Leite em pó"], product.fetch("addons").map { |addon| addon["name"] }
  end

  test "imagem definida pelo administrador é persistida e exposta no catálogo" do
    image_url = "https://cdn.example.test/produtos/calabresa.jpg"

    patch "#{products_path}/#{@product.id}", params: { product: { image_url: image_url } }, headers: auth, as: :json

    assert_response :success
    assert_equal image_url, @product.reload.image_url

    @product.update!(available: true)
    get products_path, as: :json
    assert_response :success
    assert_equal image_url, response.parsed_body.find { |item| item["id"] == @product.id }.fetch("image_url")
  end

  test "atualização de adicionais rejeita dados inválidos e preserva configuração" do
    addon = @product.addons.create!(name: "Canela", price: 1)

    patch "#{products_path}/#{@product.id}", params: { product: { addons: [{ id: addon.id, name: "", price: 0, available: true }] } }, headers: auth, as: :json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages"), "addons[0].name can't be blank"
    assert_equal "Canela", addon.reload.name
    assert_equal 1.to_d, addon.price
  end

  test "upload de imagem de produto salva arquivo local e expõe URL pública" do
    post products_path, params: { product: { category_id: @category.id, name: "Produto com foto", price: 18, available: true, image: uploaded_png } }, headers: auth

    assert_response :created
    image_url = response.parsed_body.fetch("image_url")
    assert_match %r{\A/uploads/products/restaurant-#{@restaurant.id}-product-\d+-[a-f0-9]+\.png\z}, image_url
    stored_path = Rails.root.join("public", image_url.delete_prefix("/"))
    assert stored_path.exist?
  ensure
    File.delete(stored_path) if defined?(stored_path) && stored_path&.exist?
  end

  test "upload de produto rejeita formato não suportado" do
    file = Tempfile.new(["produto", ".gif"])
    file.write("fake-gif-content")
    file.rewind

    post products_path, params: { product: { category_id: @category.id, name: "Produto inválido", price: 18, image: Rack::Test::UploadedFile.new(file.path, "image/gif") } }, headers: auth

    assert_response :unprocessable_entity
    assert_equal "validation_error", response.parsed_body["error"]
    assert_includes response.parsed_body["messages"].join, "Imagem inválida"
  ensure
    file&.close!
  end

  test "substituição de imagem remove apenas o arquivo gerenciado anterior" do
    patch "#{products_path}/#{@product.id}", params: { product: { image: uploaded_png(filename: "first.png") } }, headers: auth
    assert_response :success
    first_path = Rails.root.join("public", response.parsed_body.fetch("image_url").delete_prefix("/"))
    assert first_path.exist?

    patch "#{products_path}/#{@product.id}", params: { product: { image: uploaded_png(filename: "second.png") } }, headers: auth
    assert_response :success
    second_path = Rails.root.join("public", response.parsed_body.fetch("image_url").delete_prefix("/"))
    assert second_path.exist?
    assert_not first_path.exist?
  ensure
    File.delete(second_path) if defined?(second_path) && second_path&.exist?
  end

  test "upload de imagem sem autorização não cria arquivo" do
    assert_no_difference "Product.count" do
      post products_path, params: { product: { category_id: @category.id, name: "Sem acesso", price: 9, image: uploaded_png } }
    end
    assert_response :unauthorized
  end

  test "upload não alcança produto de outro restaurante" do
    other_restaurant = Restaurant.create!(name: "Outro Restaurante")
    other_category = Category.create!(restaurant: other_restaurant, name: "Bebidas")
    other_product = Product.create!(restaurant: other_restaurant, category: other_category, name: "Outro", price: 9)
    patch "#{products_path}/#{other_product.id}", params: { product: { image: uploaded_png } }, headers: auth

    assert_response :not_found
    assert_nil other_product.reload.image_url
  end

  test "multipart aceita listas canônicas de adicionais e variações junto da imagem" do
    patch "#{products_path}/#{@product.id}", params: { product: {
      category_id: @category.id,
      name: "Suco completo",
      description: "Importado e revisado",
      price: 14.5,
      available: true,
      image: uploaded_png,
      addons: [{ name: "Gelo", price: 1.5, available: true }],
      variants: [{ name: "500 ml", price: 14.5, available: true, position: 0 }]
    } }, headers: auth

    assert_response :success
    assert_equal "Suco completo", @product.reload.name
    assert_equal ["Gelo"], @product.addons.pluck(:name)
    assert_equal ["500 ml"], @product.variants.pluck(:name)
    assert Rails.root.join("public", response.parsed_body.fetch("image_url").delete_prefix("/")).exist?
  ensure
    delete_response_image
  end

  test "multipart aceita objetos com índices numéricos e preserva a ordem" do
    patch "#{products_path}/#{@product.id}", params: { product: {
      image: uploaded_png,
      addons: {
        "1" => { name: "Segundo", price: 2, available: true },
        "0" => { name: "Primeiro", price: 1, available: true }
      },
      variants: {
        "1" => { name: "Grande", price: 18, available: true, position: 1 },
        "0" => { name: "Pequeno", price: 12, available: true, position: 0 }
      }
    } }, headers: auth

    assert_response :success
    assert_equal ["Primeiro", "Segundo"], @product.reload.addons.order(:id).pluck(:name)
    assert_equal ["Pequeno", "Grande"], @product.variants.order(:position).pluck(:name)
  ensure
    delete_response_image
  end

  test "multipart rejeita chaves não numéricas em coleções" do
    patch "#{products_path}/#{@product.id}", params: { product: {
      image: uploaded_png,
      addons: { "inválido" => { name: "Gelo", price: 1 } }
    } }, headers: auth

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages"), "product.addons deve ser uma lista"
    assert_empty @product.reload.addons
    assert_nil @product.image_url
  end

  test "falha aninhada mantém imagem anterior e não cria arquivo órfão" do
    patch "#{products_path}/#{@product.id}", params: { product: { image: uploaded_png(filename: "original.png") } }, headers: auth
    assert_response :success
    original_url = response.parsed_body.fetch("image_url")
    original_path = Rails.root.join("public", original_url.delete_prefix("/"))

    patch "#{products_path}/#{@product.id}", params: { product: {
      name: "Nome que deve reverter",
      image: uploaded_png(filename: "replacement.png"),
      addons: [{ name: "", price: "", available: true }]
    } }, headers: auth

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages"), "addons[0].name can't be blank"
    assert_equal "Suco", @product.reload.name
    assert_equal original_url, @product.image_url
    assert original_path.exist?
  ensure
    File.delete(original_path) if defined?(original_path) && original_path&.exist?
  end

  test "upload rejeita conteúdo falso mesmo com MIME permitido" do
    patch "#{products_path}/#{@product.id}", params: { product: {
      image: uploaded_png(content_type: "image/png", bytes: "não é uma imagem")
    } }, headers: auth

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages").join, "Imagem inválida"
    assert_nil @product.reload.image_url
  end

  private

  def restaurant_path = "/api/v1/restaurants/#{@restaurant.slug}"
  def categories_path = "/api/v1/restaurants/#{@restaurant.slug}/categories"
  def products_path = "/api/v1/restaurants/#{@restaurant.slug}/products"
  def auth = { "Authorization" => "Bearer #{@owner.api_token}" }

  def delete_response_image
    return unless response&.parsed_body.is_a?(Hash)

    ProductImageStorage.new.delete_url!(response.parsed_body["image_url"])
  end
end
