require "test_helper"

class Api::V1::TenantIsolationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Tenant Principal")
    @owner = User.create!(restaurant: @restaurant, name: "Dono Principal", email: "principal@example.com", password: "secret123", role: "superAdmin")
    @category = Category.create!(restaurant: @restaurant, name: "Pratos")
    @available = Product.create!(restaurant: @restaurant, category: @category, name: "Disponível", price: 20, available: true)
    @unavailable = Product.create!(restaurant: @restaurant, category: @category, name: "Indisponível", price: 30, available: false)

    @other = Restaurant.create!(name: "Tenant Secundário")
    @other_owner = User.create!(restaurant: @other, name: "Dono Secundário", email: "secundario@example.com", password: "secret123", role: "superAdmin")
    @other_category = Category.create!(restaurant: @other, name: "Outros")
    @other_product = Product.create!(restaurant: @other, category: @other_category, name: "Produto Alheio", price: 99, available: true)
  end

  test "public catalog only exposes available records from routed restaurant" do
    get scoped("products"), as: :json
    assert_response :success
    assert_equal [@available.id], response.parsed_body.pluck("id")

    get scoped("products/#{@other_product.id}"), as: :json
    assert_response :not_found

    get "#{scoped('products')}?category_id=#{@other_category.id}", as: :json
    assert_response :not_found
  end

  test "administrative inventory requires authentication and own tenant" do
    get "#{scoped('products')}?admin=true", as: :json
    assert_response :unauthorized

    get "#{scoped('products')}?admin=true", headers: auth(@owner), as: :json
    assert_response :success
    assert_equal [@available.id, @unavailable.id].sort, response.parsed_body.pluck("id").sort

    get "/api/v1/restaurants/#{@other.slug}/products?admin=true", headers: auth(@owner), as: :json
    assert_response :not_found
  end

  test "protected mutations distinguish unauthenticated forbidden and foreign tenant access" do
    post scoped("categories"), params: { category: { name: "Nova" } }, as: :json
    assert_response :unauthorized

    employee = User.create!(restaurant: @restaurant, name: "Equipe", email: "tenant-equipe@example.com", password: "secret123", role: "funcionario", permissions: {})
    post scoped("categories"), params: { category: { name: "Nova" } }, headers: auth(employee), as: :json
    assert_response :forbidden

    post "/api/v1/restaurants/#{@other.slug}/categories", params: { category: { name: "Inválida" } }, headers: auth(@owner), as: :json
    assert_response :not_found
  end

  private

  def scoped(suffix) = "/api/v1/restaurants/#{@restaurant.slug}/#{suffix}"
  def auth(user) = { "Authorization" => "Bearer #{user.api_token}" }
end
