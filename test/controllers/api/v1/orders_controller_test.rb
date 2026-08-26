require "test_helper"
class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    category = Category.create!(name: "Lanches")
    @product = Product.create!(category: category, name: "Burger", price: 25.0)
  end
  test "rejeita pedido sem campos obrigatorios" do
    post "/api/v1/orders", params: { order: { customer_name: "A", order_type: "delivery", payment_method: "pix", items: [] } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_error", response.parsed_body["error"]
  end
  test "cria pedido delivery e retorna total" do
    post "/api/v1/orders", params: { order: { customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix", items: [{ product_id: @product.id, quantity: 2 }] } }, as: :json
    assert_response :created
    assert_equal "50.0", response.parsed_body["total"].to_s
  end
  test "cria pedido presencial identificando a mesa" do
    post "/api/v1/orders", params: { order: { customer_name: "Bruno", customer_phone: "11988888888", order_type: "dine_in", table_number: "12", payment_method: "card", items: [{ product_id: @product.id, quantity: 1 }] } }, as: :json
    assert_response :created
    assert_equal "12", response.parsed_body["table_number"]
    assert_equal "Mesa 12", response.parsed_body["table_label"]
  end

end
