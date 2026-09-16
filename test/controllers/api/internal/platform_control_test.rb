require "test_helper"

class Api::Internal::PlatformControlTest < ActionDispatch::IntegrationTest
  setup do
    %w[global@example.com unknown@example.com].each { |email| PlatformLoginRateLimiter.reset!(email: email, ip: "127.0.0.1") }
    @owner = PlatformUser.create!(name: "Global Owner", email: "global@example.com", password: "password123", role: "owner")
    @read_only = PlatformUser.create!(name: "Read Only", email: "read@example.com", password: "password123", role: "read_only")
    @auditor = PlatformUser.create!(name: "Auditor", email: "audit@example.com", password: "password123", role: "auditor")
    @restaurant = Restaurant.create!(name: "Tenant Existente")
    @tenant = @restaurant.users.create!(name: "Tenant Admin", email: "tenant@example.com", password: "password123", role: "superAdmin")
  end

  test "platform auth separates operator and tenant identities" do
    post "/api/internal/session", params: { platform_user: { email: @owner.email, password: "password123" } }, as: :json
    assert_response :success
    assert response.parsed_body["token"].present?
    assert PlatformAuditEvent.exists?(action: "platform_session.create", outcome: "success")
    get "/api/internal/restaurants", headers: bearer(@tenant.api_token), as: :json
    assert_response :unauthorized
    @owner.update!(active: false)
    post "/api/internal/session", params: { platform_user: { email: @owner.email, password: "password123" } }, as: :json
    assert_response :unauthorized
    expired = @read_only.signed_id(purpose: :platform_auth, expires_in: -1.second)
    get "/api/internal/restaurants", headers: bearer(expired), as: :json
    assert_response :unauthorized
  end

  test "platform login rate limits failures without auditing raw credentials" do
    5.times { post "/api/internal/session", params: { platform_user: { email: "unknown@example.com", password: "raw-secret" } }, as: :json }
    post "/api/internal/session", params: { platform_user: { email: "unknown@example.com", password: "raw-secret" } }, as: :json
    assert_response :too_many_requests
    serialized = PlatformAuditEvent.where(actor_identifier: "unknown@example.com").pluck(:details).to_json
    refute_includes serialized, "raw-secret"
  end

  test "read only can list but cannot mutate" do
    get "/api/internal/restaurants", headers: bearer(@read_only.api_token), as: :json
    assert_response :success
    assert_equal @restaurant.id, response.parsed_body["restaurants"].first["id"]
    post "/api/internal/restaurants", params: onboarding_payload, headers: bearer(@read_only.api_token), as: :json
    assert_response :forbidden
  end

  test "portfolio aggregate counts use grouped queries for the page" do
    Restaurant.create!(name: "Second Tenant")
    statements = []
    subscriber = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get "/api/internal/restaurants?per_page=100", headers: bearer(@owner.api_token)
    end
    assert_response :success
    grouped = statements.grep(/GROUP BY .*restaurant_id/i)
    assert_equal 4, grouped.size
  end

  test "owner provisions searches updates suspends and reactivates restaurant" do
    post "/api/internal/restaurants", params: onboarding_payload, headers: bearer(@owner.api_token), as: :json
    assert_response :created
    created = Restaurant.find(response.parsed_body.dig("restaurant", "id"))
    assert created.users.find_by(role: "superAdmin")
    get "/api/internal/restaurants?query=provisioned&status=active", headers: bearer(@owner.api_token)
    assert_response :success
    assert_equal [created.id], response.parsed_body["restaurants"].map { |item| item["id"] }
    assert response.parsed_body["restaurants"].first["counts"].key?("users")
    patch "/api/internal/restaurants/#{created.id}", params: { restaurant: { name: "Provisioned Updated" } }, headers: bearer(@owner.api_token), as: :json
    assert_response :success
    post "/api/internal/restaurants/#{created.id}/suspend", params: { reason: "Contrato pausado" }, headers: bearer(@owner.api_token), as: :json
    assert_response :success
    assert created.reload.suspended?
    post "/api/internal/restaurants/#{created.id}/suspend", params: { reason: "Again" }, headers: bearer(@owner.api_token), as: :json
    assert_response :conflict
    post "/api/internal/restaurants/#{created.id}/reactivate", headers: bearer(@owner.api_token), as: :json
    assert_response :success
    refute created.reload.suspended?
  end

  test "auditor filters history and diagnostics contain build identity" do
    PlatformAudit.record(action: "restaurant.update", outcome: "success", actor: @owner, target: @restaurant)
    get "/api/internal/audit_events?restaurant_id=#{@restaurant.id}&outcome=success", headers: bearer(@auditor.api_token)
    assert_response :success
    assert_equal @restaurant.id, response.parsed_body["events"].first["target_id"]
    get "/api/internal/audit_events", headers: bearer(@read_only.api_token), as: :json
    assert_response :forbidden
    get "/api/internal/diagnostics", headers: bearer(@read_only.api_token), as: :json
    assert_response :success
    assert_equal %w[built_at commit services version], response.parsed_body.keys.sort
  end

  test "public onboarding route is absent" do
    assert_no_difference ["Restaurant.count", "User.count"] do
      post "/api/v1/restaurants", params: onboarding_payload, as: :json
      assert_response :not_found
    end
  end

  private

  def bearer(token) = { "Authorization" => "Bearer #{token}" }
  def onboarding_payload = { restaurant: { name: "Provisioned Tenant", slug: "provisioned-tenant" }, super_admin: { name: "Provisioned Owner", email: "provisioned@example.com", password: "password123", password_confirmation: "password123" } }
end
