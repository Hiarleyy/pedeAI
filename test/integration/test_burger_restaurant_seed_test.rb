require "test_helper"

class TestBurgerRestaurantSeedTest < ActiveSupport::TestCase
  test "seed usa preços absolutos e mantém contagens ao executar novamente" do
    seed = Rails.root.join("db/seeds/test_burger_restaurant.rb")
    capture_io { load seed }
    restaurant = Restaurant.find_by!(slug: "burger-lab")
    first_counts = [restaurant.products.count, ProductVariant.joins(:product).where(products: { restaurant_id: restaurant.id }).count, ProductAddon.joins(:product).where(products: { restaurant_id: restaurant.id }).count]

    capture_io { load seed }
    restaurant.reload

    assert_equal first_counts, [restaurant.products.count, ProductVariant.joins(:product).where(products: { restaurant_id: restaurant.id }).count, ProductAddon.joins(:product).where(products: { restaurant_id: restaurant.id }).count]
    bacon = restaurant.products.find_by!(name: "Bacon Supreme")
    variant = bacon.variants.find_by!(name: "Carne 220g")
    assert_equal 38.9.to_d, variant.price
    assert_equal 44.4.to_d, OrderItemPrice.calculate(product: bacon, variant: variant, addons: [bacon.addons.find_by!(name: "Bacon extra")])
  end
end
