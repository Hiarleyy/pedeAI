require "test_helper"
require "yaml"

class Api::V1::OpenapiContractTest < ActiveSupport::TestCase
  CANONICAL_PATHS = %w[
    /api/v1/session
    /api/v1/restaurants
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

  LEGACY_PATHS = %w[/api/v1/categories /api/v1/products /api/v1/orders /api/v1/users].freeze

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
  end
end
