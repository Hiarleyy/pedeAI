require "test_helper"

class RestaurantDeletionTest < ActiveSupport::TestCase
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Encerrado", status: "suspended", suspension_reason: "Encerrado", suspended_at: Time.current)
    @user = @restaurant.users.create!(name: "Responsável", email: "deletion-owner@example.com", password: "password123", role: "superAdmin")
    category = @restaurant.categories.create!(name: "Pratos")
    @product = @restaurant.products.create!(category: category, name: "Prato", price: 25)
    @variant = @product.variants.create!(name: "Grande", price: 30, position: 0)
    @product_addon = @product.addons.create!(name: "Extra", price: 3)
    @order = @restaurant.orders.build(customer_name: "Cliente", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix")
    @order.order_items.build(product: @product, quantity: 1, unit_price: @product.price)
    @order.save!
    @order_item = @order.order_items.first
    @order_item_addon = @order_item.addons.create!(name: "Extra", price: 3)
  end

  test "destroys a tenant and every dependent record" do
    ids = [@restaurant.id, @user.id, @product.id, @variant.id, @product_addon.id, @order.id, @order_item.id, @order_item_addon.id]

    @restaurant.destroy_tenant!

    refute Restaurant.exists?(ids[0])
    refute User.exists?(ids[1])
    refute Product.exists?(ids[2])
    refute ProductVariant.exists?(ids[3])
    refute ProductAddon.exists?(ids[4])
    refute Order.exists?(ids[5])
    refute OrderItem.exists?(ids[6])
    refute OrderItemAddon.exists?(ids[7])
    refute Category.where(restaurant_id: @restaurant.id).exists?
  end

  test "rolls back a tenant deletion when the surrounding operation fails" do
    Restaurant.transaction do
      @restaurant.destroy_tenant!
      raise ActiveRecord::Rollback
    end

    assert Restaurant.exists?(@restaurant.id)
    assert User.exists?(@user.id)
    assert Product.exists?(@product.id)
    assert Order.exists?(@order.id)
    assert OrderItemAddon.exists?(@order_item_addon.id)
  end
end
