require "test_helper"

class RestaurantTest < ActiveSupport::TestCase
  test "valida fontes suportadas" do
    restaurant = Restaurant.new(name: "Pizzaria Boa", font_family: "poppins")
    assert restaurant.valid?
  end

  test "rejeita fontes nao suportadas" do
    restaurant = Restaurant.new(name: "Pizzaria Boa", font_family: "comic-sans")
    assert_not restaurant.valid?
    assert_includes restaurant.errors[:font_family], "is not included in the list"
  end

  test "atribui inter por padrao" do
    restaurant = Restaurant.create!(name: "Pizzaria Padrao")
    assert_equal "inter", restaurant.font_family
  end

  test "normaliza e serializa informações vazias do cardápio" do
    restaurant = Restaurant.create!(name: "Pizzaria Sem Perfil")

    assert_equal "America/Sao_Paulo", restaurant.menu_information["timezone"]
    assert_equal false, restaurant.menu_information.dig("visibility", "operating")
    assert_equal restaurant.menu_information, restaurant.as_json["menu_information"]
    assert_includes restaurant.as_json, "menu_information_status"
  end

  test "valida e calcula as informações públicas do restaurante" do
    restaurant = Restaurant.new(name: "Pizzaria Informada", menu_information: {
      "timezone" => "America/Sao_Paulo",
      "hours" => { "1" => [{ "open" => "10:00", "close" => "22:00", "enabled" => true }] },
      "delivery" => { "estimate" => "30-45 min", "fee" => 5.5 },
      "location" => { "address" => "Rua das Flores, 10", "map_url" => "https://maps.example.com/pizzaria" },
      "contact" => { "phone" => "11999999999", "whatsapp" => "11999999999" },
      "social" => { "instagram" => "https://instagram.com/pizzaria", "facebook" => "https://facebook.com/pizzaria", "website" => "https://pizzaria.example.com" },
      "visibility" => { "operating" => true, "delivery" => true, "location" => true, "contact" => true, "social" => true }
    })

    assert restaurant.valid?
    restaurant_time = ActiveSupport::TimeZone["America/Sao_Paulo"].parse("2026-09-07 12:00:00")
    status = restaurant.menu_information_status(now: restaurant_time)
    assert_equal true, status["open"]
    assert_equal "22:00", status["closes_at"]
    assert_equal "30-45 min", restaurant.as_json.dig("menu_information", "delivery", "estimate")
    assert_includes restaurant.as_json.fetch("menu_information_status"), "open"
  end

  test "rejeita perfil de informações inválido" do
    restaurant = Restaurant.new(name: "Pizzaria Inválida", menu_information: { "timezone" => "Invalid/Zone", "delivery" => { "fee" => -1 }, "social" => { "website" => "http://inseguro.example.com" } })

    assert_not restaurant.valid?
    assert_includes restaurant.errors[:menu_information].join, "timezone"
  end

  test "identifica funcionamento em intervalo que atravessa a meia-noite" do
    restaurant = Restaurant.new(name: "Pizzaria Noturna", menu_information: {
      "hours" => { "1" => [{ "open" => "22:00", "close" => "02:00", "enabled" => true }] },
      "visibility" => { "operating" => true, "delivery" => false, "location" => false, "contact" => false, "social" => false }
    })

    status = restaurant.menu_information_status(now: Time.zone.parse("2026-09-08 01:00:00"))
    assert_equal true, status["open"]
    assert_equal "02:00", status["closes_at"]
  end
end
