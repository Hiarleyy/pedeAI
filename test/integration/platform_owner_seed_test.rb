require "test_helper"

class PlatformOwnerSeedTest < ActiveSupport::TestCase
  test "default platform owner seed is idempotent" do
    with_platform_owner_environment(nil, nil, nil) do
      2.times { capture_io { load Rails.root.join("db/seeds.rb") } }

      owner = PlatformUser.find_by!(email: "admincontrol@pedeai.dev")
      assert_equal "owner", owner.role
      assert owner.active?
      assert owner.authenticate("pedeaiDev")
      assert_equal 1, PlatformUser.where(email: owner.email).count
    end
  end

  test "platform owner seed honors environment overrides" do
    with_platform_owner_environment("operator@example.com", "customPassword", "Custom Operator") do
      capture_io { load Rails.root.join("db/seeds.rb") }

      owner = PlatformUser.find_by!(email: "operator@example.com")
      assert_equal "Custom Operator", owner.name
      assert owner.authenticate("customPassword")
    end
  end

  private

  def with_platform_owner_environment(email, password, name)
    keys = %w[PLATFORM_OWNER_EMAIL PLATFORM_OWNER_PASSWORD PLATFORM_OWNER_NAME]
    previous = ENV.to_h.slice(*keys)
    keys.zip([email, password, name]).each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    keys.each { |key| previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key) }
  end
end
