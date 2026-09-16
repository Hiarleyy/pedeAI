require "test_helper"

class Api::V1::RestaurantSuspensionTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Suspended Tenant", status: "suspended", suspension_reason: "Test", suspended_at: Time.current)
    @admin = @restaurant.users.create!(name: "Tenant Owner", email: "suspended@example.com", password: "password123", role: "superAdmin")
  end

  test "catalog remains readable while orders and admin mutations are blocked" do
    get "/api/v1/restaurants/#{@restaurant.slug}"
    assert_response :success
    get "/api/v1/restaurants/#{@restaurant.slug}/categories"
    assert_response :success
    assert_no_difference "Order.count" do
      post "/api/v1/restaurants/#{@restaurant.slug}/orders", params: { order: {} }, as: :json
      assert_response :conflict
      assert_equal "restaurant_suspended", response.parsed_body["error"]
    end
    assert_no_difference "Category.count" do
      post "/api/v1/restaurants/#{@restaurant.slug}/categories", params: { category: { name: "Blocked" } }, headers: { "Authorization" => "Bearer #{@admin.api_token}" }, as: :json
      assert_response :conflict
      assert_equal "restaurant_suspended", response.parsed_body["error"]
    end
  end

  test "every tenant administrative mutation family uses the suspension guard" do
    headers = { "Authorization" => "Bearer #{@admin.api_token}" }
    requests = [
      -> { patch "/api/v1/restaurants/#{@restaurant.slug}", params: { restaurant: { name: "Blocked" } }, headers: headers, as: :json },
      -> { post "/api/v1/restaurants/#{@restaurant.slug}/products", params: { product: {} }, headers: headers, as: :json },
      -> { post "/api/v1/restaurants/#{@restaurant.slug}/users", params: { user: {} }, headers: headers, as: :json },
      -> { post "/api/v1/restaurants/#{@restaurant.slug}/menu-import", headers: headers },
      -> { patch "/api/v1/restaurants/#{@restaurant.slug}/orders/999", params: { order: { status: "confirmed" } }, headers: headers, as: :json }
    ]

    requests.each do |perform|
      perform.call
      assert_response :conflict
      assert_equal "restaurant_suspended", response.parsed_body["error"]
    end
  end
end
