require "test_helper"

class OrderItemPriceTest < ActiveSupport::TestCase
  setup do
    restaurant = Restaurant.create!(name: "Restaurante Preços")
    category = restaurant.categories.create!(name: "Lanches")
    @product = restaurant.products.create!(category: category, name: "Burger", price: 25)
    @variant = @product.variants.create!(name: "Duplo", price: 32.9)
    @cheese = @product.addons.create!(name: "Queijo", price: 4.5)
    @bacon = @product.addons.create!(name: "Bacon", price: 6)
  end

  test "soma adicionais ao preço base quando não há variação" do
    assert_equal 35.5.to_d, OrderItemPrice.calculate(product: @product, addons: [@cheese, @bacon])
  end

  test "usa preço absoluto da variação e soma adicionais sem duplicar o preço base" do
    assert_equal 43.4.to_d, OrderItemPrice.calculate(product: @product, variant: @variant, addons: [@cheese, @bacon])
  end
end
