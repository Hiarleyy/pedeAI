require "test_helper"
require "yaml"

class Api::V1::OpenapiContractTest < ActiveSupport::TestCase
  CANONICAL_PATHS = %w[
    /api/v1/session
    /api/internal/session
    /api/internal/restaurants
    /api/internal/restaurants/{id}
    /api/internal/restaurants/{id}/suspend
    /api/internal/restaurants/{id}/reactivate
    /api/internal/audit_events
    /api/internal/diagnostics
    /api/v1/restaurants/{restaurant_slug}
    /api/v1/restaurants/{restaurant_slug}/categories
    /api/v1/restaurants/{restaurant_slug}/categories/{id}
    /api/v1/restaurants/{restaurant_slug}/products
    /api/v1/restaurants/{restaurant_slug}/products/{id}
    /api/v1/restaurants/{restaurant_slug}/menu-import
    /api/v1/restaurants/{restaurant_slug}/orders
    /api/v1/restaurants/{restaurant_slug}/orders/{id}
    /api/v1/restaurants/{restaurant_slug}/users
    /api/v1/restaurants/{restaurant_slug}/users/{id}
  ].freeze

  LEGACY_PATHS = %w[/api/v1/categories /api/v1/products /api/v1/orders /api/v1/users /api/v1/restaurants].freeze

  test "OpenAPI parses and declares the canonical route set without legacy paths" do
    document = YAML.safe_load(Rails.root.join("docs/openapi.yaml").read)
    paths = document.fetch("paths")

    assert_equal "3.1.0", document.fetch("openapi")
    CANONICAL_PATHS.each { |path| assert paths.key?(path), "OpenAPI is missing #{path}" }
    LEGACY_PATHS.each { |path| refute paths.key?(path), "OpenAPI still declares #{path}" }
    refute paths.key?("/api/v1/restaurants/{restaurant_slug}/menu-ocr-imports")
  end

  test "protected operations declare bearer authentication" do
    document = YAML.safe_load(Rails.root.join("docs/openapi.yaml").read)
    paths = document.fetch("paths")

    assert paths.dig("/api/v1/restaurants/{restaurant_slug}", "patch", "security")
    assert paths.dig("/api/v1/restaurants/{restaurant_slug}/orders", "get", "security")
    assert paths.dig("/api/v1/restaurants/{restaurant_slug}/users", "post", "security")
    assert_nil paths.dig("/api/v1/restaurants/{restaurant_slug}/orders", "post", "security")
    assert paths.dig("/api/internal/restaurants", "post", "security")
  end

  test "order creation documents the closed restaurant conflict" do
    document = YAML.safe_load(Rails.root.join("docs/openapi.yaml").read)
    response = document.dig("paths", "/api/v1/restaurants/{restaurant_slug}/orders", "post", "responses", "409")

    assert_equal "#/components/responses/RestaurantClosed", response.fetch("$ref")
    schema = document.dig("components", "schemas", "RestaurantClosedError")
    assert_equal %w[error messages next_opening], schema.fetch("required")
    assert_equal "restaurant_closed", schema.dig("properties", "error", "const")
  end

  test "OpenAPI documenta composição de preço personalizado" do
    document = YAML.safe_load(Rails.root.join("docs/openapi.yaml").read)
    schemas = document.dig("components", "schemas")

    assert_includes schemas.dig("ProductInput", "properties", "variants", "description"), "preço final absoluto"
    assert_includes schemas.dig("ProductAddonInput", "properties", "price", "description"), "Acréscimo"
    assert_includes schemas.dig("ProductVariantInput", "properties", "price", "description"), "Preço final absoluto"
    assert schemas.dig("OrderCreateRequest", "properties", "order", "properties", "items", "items", "properties", "variant_id")
    assert_includes schemas.dig("OrderItem", "properties", "unit_price", "description"), "adicionais"
  end
end
