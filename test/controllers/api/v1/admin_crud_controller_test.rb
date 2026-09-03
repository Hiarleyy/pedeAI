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
    get products_path, as: :json
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

  private

  def categories_path = "/api/v1/restaurants/#{@restaurant.slug}/categories"
  def products_path = "/api/v1/restaurants/#{@restaurant.slug}/products"
  def auth = { "Authorization" => "Bearer #{@owner.api_token}" }
end
