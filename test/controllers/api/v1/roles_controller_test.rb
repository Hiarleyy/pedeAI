require "test_helper"

class Api::V1::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "PedeAI Centro")
    @owner = User.create!(name: "Dono", email: "dono@example.com", password: "secret123", role: "superAdmin", restaurant: @restaurant)
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "secret123", role: "admin", restaurant: @restaurant)
    @employee = User.create!(name: "Equipe", email: "equipe@example.com", password: "secret123", role: "funcionario", restaurant: @restaurant)
  end

  test "cria restaurante com seu único superAdmin" do
    post "/api/v1/restaurants", params: {
      restaurant: { name: "PedeAI Norte" },
      super_admin: { name: "Dona Norte", email: "dona.norte@example.com", password: "secret123", password_confirmation: "secret123" }
    }, as: :json

    assert_response :created
    restaurant = Restaurant.find(response.parsed_body.dig("restaurant", "id"))
    assert_equal "pedeai-norte", restaurant.slug
    assert_equal ["superAdmin"], restaurant.users.pluck(:role)
    assert_equal "dona.norte@example.com", response.parsed_body.dig("super_admin", "email")
  end

  test "criação inválida não deixa restaurante sem superAdmin" do
    assert_no_difference "Restaurant.count" do
      post "/api/v1/restaurants", params: {
        restaurant: { name: "PedeAI Norte" },
        super_admin: { name: "Dona Norte", email: "invalido", password: "secret123" }
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "superAdmin cria e gerencia administrador" do
    get "/api/v1/restaurants/#{@restaurant.slug}/users", headers: auth(@owner), as: :json
    assert_response :success

    post "/api/v1/restaurants/#{@restaurant.slug}/users", params: { user: { name: "Novo Admin", email: "novo.admin@example.com", password: "secret123", role: "admin" } }, headers: auth(@owner), as: :json

    assert_response :created
    managed_admin = User.find(response.parsed_body["id"])

    patch "/api/v1/restaurants/#{@restaurant.slug}/users/#{managed_admin.id}", params: { user: { name: "Admin Atualizado", role: "admin", permissions: {} } }, headers: auth(@owner), as: :json
    assert_response :success
    assert_equal "Admin Atualizado", managed_admin.reload.name

    delete "/api/v1/restaurants/#{@restaurant.slug}/users/#{managed_admin.id}", headers: auth(@owner), as: :json
    assert_response :no_content
    assert_not User.exists?(managed_admin.id)
  end

  test "admin cria e gerencia apenas funcionários" do
    post "/api/v1/restaurants/#{@restaurant.slug}/users", params: { user: { name: "Novo", email: "novo@example.com", password: "secret123", role: "funcionario", permissions: { "orders:read" => true } } }, headers: auth(@admin), as: :json

    assert_response :created
    employee = User.find(response.parsed_body["id"])

    patch "/api/v1/restaurants/#{@restaurant.slug}/users/#{employee.id}", params: { user: { name: "Equipe Atualizada", role: "funcionario", permissions: { "users:read" => true } } }, headers: auth(@admin), as: :json
    assert_response :success

    post "/api/v1/restaurants/#{@restaurant.slug}/users", params: { user: { name: "Outro Admin", email: "outro.admin@example.com", password: "secret123", role: "admin" } }, headers: auth(@admin), as: :json
    assert_response :forbidden
  end

  test "admin não pode gerenciar administrador e funcionário não pode criar usuários" do
    patch "/api/v1/restaurants/#{@restaurant.slug}/users/#{@admin.id}", params: { user: { name: "Admin Alterado" } }, headers: auth(@admin), as: :json
    assert_response :forbidden

    post "/api/v1/restaurants/#{@restaurant.slug}/users", params: { user: { name: "Outro", email: "outro@example.com", password: "secret123", role: "funcionario" } }, headers: auth(@employee), as: :json
    assert_response :forbidden
  end

  test "superAdmin não pode ser removido ou rebaixado" do
    delete "/api/v1/restaurants/#{@restaurant.slug}/users/#{@owner.id}", headers: auth(@owner), as: :json
    assert_response :unprocessable_entity

    patch "/api/v1/restaurants/#{@restaurant.slug}/users/#{@owner.id}", params: { user: { role: "admin" } }, headers: auth(@owner), as: :json
    assert_response :unprocessable_entity
    assert_equal "superAdmin", @owner.reload.role
  end

  test "superAdmin não acessa usuários de outro restaurante" do
    other_restaurant = Restaurant.create!(name: "PedeAI Sul")
    other_owner = User.create!(name: "Dona Sul", email: "sul@example.com", password: "secret123", role: "superAdmin", restaurant: other_restaurant)

    get "/api/v1/restaurants/#{other_restaurant.slug}/users", headers: auth(@owner), as: :json

    assert_response :not_found
    assert User.exists?(other_owner.id)
  end

  test "admin atualiza configurações visuais somente do próprio restaurante" do
    patch "/api/v1/restaurants/#{@restaurant.slug}", params: {
      restaurant: {
        name: "PedeAI Centro Premium",
        menu_description: "Culinária artesanal",
        banner_url: "https://example.com/banner.jpg",
        logo_url: "https://example.com/logo.png",
        product_placeholder_url: "https://example.com/placeholder.png",
        primary_color: "#b72e00"
      }
    }, headers: auth(@admin), as: :json

    assert_response :success
    assert_equal "Culinária artesanal", @restaurant.reload.menu_description
    assert_equal "#b72e00", @restaurant.primary_color
    assert_equal "https://example.com/placeholder.png", @restaurant.product_placeholder_url
  end

  test "admin atualiza perfil de informações do restaurante" do
    profile = {
      timezone: "America/Sao_Paulo",
      hours: { "1" => [{ open: "10:00", close: "22:00", enabled: true }] },
      delivery: { estimate: "30-45 min", fee: 4.5 },
      location: { address: "Rua Central, 100", map_url: "https://maps.example.com/central" },
      contact: { phone: "11999999999", whatsapp: "11999999999" },
      social: { instagram: "https://instagram.com/pedeai", facebook: "https://facebook.com/pedeai", website: "https://pedeai.example.com" },
      visibility: { operating: true, delivery: true, location: true, contact: true, social: true }
    }

    patch "/api/v1/restaurants/#{@restaurant.slug}", params: { restaurant: { menu_information: profile } }, headers: auth(@admin), as: :json

    assert_response :success
    assert_equal "30-45 min", response.parsed_body.dig("menu_information", "delivery", "estimate")
    assert_equal true, response.parsed_body.dig("menu_information", "visibility", "delivery")
  end

  test "funcionário não atualiza configurações do restaurante" do
    patch "/api/v1/restaurants/#{@restaurant.slug}", params: {
      restaurant: { name: "Nome indevido" }
    }, headers: auth(@employee), as: :json

    assert_response :forbidden
    assert_not_equal "Nome indevido", @restaurant.reload.name
  end
  private

  def auth(user)
    { "Authorization" => "Bearer #{user.api_token}" }
  end
end



