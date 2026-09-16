class RestaurantOnboarding
  attr_reader :restaurant, :super_admin

  def initialize(restaurant_attributes:, super_admin_attributes:)
    @restaurant = Restaurant.new(restaurant_attributes)
    @super_admin = @restaurant.users.build(super_admin_attributes.merge(role: "superAdmin", permissions: {}))
  end

  def call!
    Restaurant.transaction do
      restaurant.save!
      super_admin.save!
    end
    self
  end
end
