require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Responsivo")
  end

  test "mantem o cardapio desktop na rota atual" do
    get "/cardapio/#{@restaurant.slug}", headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
    assert_response :success
    assert_includes response.body, "Nonna's Trattoria"
    assert_not_includes response.body, "mobile-menu"
  end

  test "renderiza arquivo mobile na mesma rota para celular" do
    get "/cardapio/#{@restaurant.slug}", headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile" }
    assert_response :success
    assert_includes response.body, "mobile-menu"
    assert_not_includes response.body, "Nonna's Trattoria"
  end
end
