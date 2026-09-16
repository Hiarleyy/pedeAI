require "test_helper"

class PlatformUserTest < ActiveSupport::TestCase
  test "is independent from restaurants and has fixed deny-by-default permissions" do
    user = PlatformUser.create!(name: "Platform Owner", email: "OWNER@EXAMPLE.COM", password: "password123", role: "owner")
    assert_equal "owner@example.com", user.email
    assert_nil user.attributes["restaurant_id"]
    assert user.allowed?("restaurants:create")
    refute user.allowed?("unknown:permission")
    assert_raises(ActiveRecord::RecordInvalid) { PlatformUser.create!(name: "Invalid", email: "invalid@example.com", password: "password123", role: "superAdmin") }
  end
end
