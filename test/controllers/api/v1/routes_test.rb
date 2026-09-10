require "test_helper"

class Api::V1::RoutesTest < ActionDispatch::IntegrationTest
  CANONICAL_PATHS = {
    get: %w[categories categories/1 products products/1 orders orders/1 users],
    post: %w[categories products menu-import orders users],
    patch: %w[categories/1 products/1 orders/1 users/1],
    delete: %w[categories/1 products/1 users/1]
  }.freeze

  test "recognizes canonical restaurant-scoped and global routes" do
    CANONICAL_PATHS.each do |method, suffixes|
      suffixes.each do |suffix|
        controller = suffix == "menu-import" ? "menu_imports" : suffix.split("/").first
        expected = { controller: "api/v1/#{controller}", action: action_for(method, suffix), restaurant_slug: "casa" }
        expected[:id] = suffix[/\d+/] if suffix.match?(%r{/\d+\z})
        assert_recognizes(expected, { path: "/api/v1/restaurants/casa/#{suffix}", method: method })
      end
    end

    assert_routing({ path: "/api/v1/session", method: :post }, controller: "api/v1/sessions", action: "create")
    assert_routing({ path: "/api/v1/restaurants", method: :post }, controller: "api/v1/restaurants", action: "create")
    assert_routing({ path: "/api/v1/restaurants/casa", method: :get }, controller: "api/v1/restaurants", action: "show", restaurant_slug: "casa")
  end

  test "favicon responde sem erro de roteamento" do
    get "/favicon.ico"

    assert_response :no_content
  end

  test "does not recognize legacy unscoped resource routes" do
    %w[categories products orders users].each do |resource|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("/api/v1/#{resource}", method: :get)
      end
    end
  end

  test "does not recognize removed OCR import routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/api/v1/restaurants/casa/menu-ocr-imports", method: :post)
    end
  end

  private

  def action_for(method, suffix)
    return "create" if suffix == "menu-import"
    return "index" if method == :get && !suffix.match?(%r{/\d+\z})
    return "show" if method == :get
    return "create" if method == :post
    return "update" if method == :patch

    "destroy"
  end
end
