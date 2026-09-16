require "test_helper"

class SuspiciousVariantPriceAuditTest < ActiveSupport::TestCase
  test "lista preços suspeitos sem alterar dados e exclui demonstração" do
    regular = Restaurant.create!(name: "Restaurante Regular")
    category = regular.categories.create!(name: "Lanches")
    product = regular.products.create!(category: category, name: "Burger", price: 25)
    suspicious = product.variants.create!(name: "Grande", price: 5)
    product.variants.create!(name: "Premium", price: 30)

    demo = Restaurant.create!(name: "Burger Lab", slug: "burger-lab")
    demo_category = demo.categories.create!(name: "Lanches")
    demo_product = demo.products.create!(category: demo_category, name: "Demo", price: 20)
    demo_product.variants.create!(name: "Delta antigo", price: 4)

    ids = SuspiciousVariantPriceAudit.call.pluck(:id)

    assert_equal [suspicious.id], ids
    assert_equal 5.to_d, suspicious.reload.price
  end
end
