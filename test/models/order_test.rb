require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Testes")
    @category = Category.create!(restaurant: @restaurant, name: "Testes")
    @product = Product.create!(restaurant: @restaurant, category: @category, name: "Prato", price: 20.0)
  end

  test "exige endereco para delivery" do
    order = Order.new(restaurant: @restaurant, customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", payment_method: "pix")
    order.valid?
    assert_includes order.errors[:delivery_address], "can't be blank"
  end

  test "exige mesa para atendimento presencial" do
    order = Order.new(restaurant: @restaurant, customer_name: "Ana", customer_phone: "11999999999", order_type: "dine_in", payment_method: "pix")
    order.valid?
    assert_includes order.errors[:table_number], "can't be blank"
  end

  test "calcula total usando preco do produto" do
    order = Order.create!(restaurant: @restaurant, customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix")
    order.order_items.create!(product: @product, quantity: 3)
    order.save!
    assert_equal 60.to_d, order.reload.total
  end
end
