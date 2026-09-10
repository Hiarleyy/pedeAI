require "test_helper"

class Api::V1::RestaurantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Público")
  end

  test "recurso público do restaurante serializa informações do cardápio" do
    get "/api/v1/restaurants/#{@restaurant.slug}", as: :json

    assert_response :success
    assert_equal @restaurant.id, response.parsed_body["id"]
    assert_equal "America/Sao_Paulo", response.parsed_body.dig("menu_information", "timezone")
    assert_equal false, response.parsed_body.dig("menu_information", "visibility", "operating")
    assert_includes response.parsed_body, "menu_information_status"
  end
end
