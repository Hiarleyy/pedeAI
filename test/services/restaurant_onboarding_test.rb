require "test_helper"

class RestaurantOnboardingTest < ActiveSupport::TestCase
  test "atomically creates restaurant and super admin" do
    result = RestaurantOnboarding.new(restaurant_attributes: { name: "Tenant Novo" }, super_admin_attributes: { name: "Owner Tenant", email: "owner@tenant.test", password: "password123", password_confirmation: "password123" }).call!
    assert result.restaurant.persisted?
    assert result.super_admin.persisted?
    assert result.super_admin.super_admin?
  end

  test "rolls back restaurant when owner is invalid" do
    assert_no_difference ["Restaurant.count", "User.count"] do
      assert_raises(ActiveRecord::RecordInvalid) { RestaurantOnboarding.new(restaurant_attributes: { name: "Tenant Inválido" }, super_admin_attributes: { name: "Owner Tenant", email: "bad", password: "password123" }).call! }
    end
  end
end
