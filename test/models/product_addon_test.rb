require "test_helper"

class ProductAddonTest < ActiveSupport::TestCase
  setup do
    restaurant = Restaurant.create!(name: "Restaurante Adicionais")
    category = Category.create!(restaurant: restaurant, name: "Lanches")
    @product = Product.create!(restaurant: restaurant, category: category, name: "Hambúrguer", price: 20)
  end

  test "exige nome único por produto e preço positivo" do
    @product.addons.create!(name: "Queijo", price: 3)
    duplicate = @product.addons.build(name: "queijo", price: 3)
    invalid_price = @product.addons.build(name: "Bacon", price: 0)

    assert_not duplicate.valid?
    assert_not invalid_price.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert_includes invalid_price.errors[:price], "must be greater than 0"
  end
end
