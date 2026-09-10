require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Responsivo")
  end

  test "mantem o cardapio desktop na rota atual" do
    get "/cardapio/#{@restaurant.slug}", headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
    assert_response :success
    assert_includes response.body, "class=\"menu-layout\""
    assert_includes response.body, "id=\"category-nav\""
    assert_includes response.body, "id=\"cart\""
    assert_includes response.body, "id=\"product-detail\""
    assert_includes response.body, "id=\"share\""
    assert_includes response.body, "id=\"track-order-fab\""
    assert_includes response.body, "id=\"order-tracking\""
    assert_includes response.body, "id=\"tracking-form\""
    assert_includes response.body, "/orders/track?query="
    assert_includes response.body, "tracking-timeline"
    assert_not_includes response.body, "confirmation-time"
    assert_includes response.body, "variant_id:item.variant?.id"
    assert_includes response.body, "navigator.share"
    assert_includes response.body, "loadGoogleFont"
    assert_includes response.body, "prefers-reduced-motion"
    assert_not_includes response.body, "window.prompt"
    assert_not_includes response.body, "window.confirm"
    assert_not_includes response.body, "Bruschetta Tradicional"
    assert_not_includes response.body, "mobile-menu"
    assert_includes response.body, "data-restaurant-slug=\"#{@restaurant.slug}\""
    assert_includes response.body, "/api/v1/restaurants/"
  end

  test "renderiza arquivo mobile na mesma rota para celular" do
    get "/cardapio/#{@restaurant.slug}", headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile" }
    assert_response :success
    assert_includes response.body, "mobile-menu"
    assert_includes response.body, "id=\"cart-bar\""
    assert_includes response.body, "id=\"track-order-fab\""
    assert_includes response.body, "id=\"order-tracking\""
    assert_includes response.body, "id=\"tracking-form\""
    assert_includes response.body, "/orders/track?query="
    assert_includes response.body, "tracking-timeline"
    assert_includes response.body, "aria-label=\"Ver sacola\""
    assert_includes response.body, "Ver sacola com ${count}"
    assert_includes response.body, "class=\"cart-count\""
    assert_not_includes response.body, "cart-bar-copy"
    assert_includes response.body, "id=\"cart-count\""
    assert_includes response.body, "#cart-count\").textContent = count"
    assert_not_includes response.body, "id=\"cart-total\""
    assert_includes response.body, "product-detail"
    assert_includes response.body, "detail-add"
    assert_includes response.body, ".detail-addons + .detail-addons"
    assert_includes response.body, "grid-template-columns: 18px minmax(0, 1fr) auto"
    assert_includes response.body, ".detail-note textarea { display: block; width: 100%"
    assert_includes response.body, "id=\"share-feedback\""
    assert_includes response.body, "navigator.share(shareData)"
    assert_includes response.body, "copyMenuLink(url)"
    assert_not_includes response.body, "onclick=\"history.back()\""
    assert_not_includes response.body, "class=\"round-button back\""
    assert_includes response.body, "data-back-to-menu"
    assert_not_includes response.body, "window.prompt"
    assert_not_includes response.body, "window.confirm"
    assert_not_includes response.body, "Nonna's Trattoria"
    assert_includes response.body, "data-restaurant-slug=\"#{@restaurant.slug}\""
    assert_includes response.body, "/api/v1/restaurants/"
  end

  test "painel administrativo recebe contexto do restaurante" do
    get "/admin/#{@restaurant.slug}"

    assert_response :success
    assert_includes response.body, "data-restaurant-slug=\"#{@restaurant.slug}\""
    assert_includes response.body, "restaurantResource('products') + '?admin=true'"
    assert_includes response.body, "admin-login-split-screen"
    assert_includes response.body, "admin-login-visual"
    assert_includes response.body, "Plus+Jakarta+Sans"
    assert_includes response.body, "v-model=\"adminAuth.email\""
    assert_includes response.body, "v-model=\"adminAuth.password\""
    assert_includes response.body, "api/v1/session"
    assert_not_includes response.body, "admin123"
    assert_not_includes response.body, "Ou continue com"
    assert_equal "text/html; charset=utf-8", response.media_type + "; charset=#{response.charset}"
  end

  test "arquivos de documentação são servidos com UTF-8" do
    get "/docs"
    assert_response :success
    assert_equal "utf-8", response.charset

    get "/openapi.yaml"
    assert_response :success
    assert_equal "utf-8", response.charset
  end

  test "clientes empacotados não chamam recursos legados" do
    clients = %w[docs/admin.html docs/menu.html docs/menu-mobile.html].to_h do |path|
      [path, Rails.root.join(path).read]
    end

    clients.each do |path, source|
      refute_match(%r{(?:fetch|apiRequest)\([^\n]*["'`]\/api\/v1\/(?:categories|products|orders|users)}, source, path)
    end
  end

  test "clientes empacotados suportam customizacao de tipografia" do
    get "/cardapio/#{@restaurant.slug}"
    assert_response :success
    assert_includes response.body, "--font-family"
    assert_includes response.body, "loadGoogleFont"

    get "/cardapio/#{@restaurant.slug}", headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile" }
    assert_response :success
    assert_includes response.body, "--font-family"
    assert_includes response.body, "loadGoogleFont"

    get "/admin/#{@restaurant.slug}"
    assert_response :success
    assert_includes response.body, "Tipografia do cardápio"
    assert_includes response.body, "supportedFonts"
  end

  test "clientes empacotados oferecem feedback de movimento acessivel" do
    desktop = Rails.root.join("docs/menu.html").read
    mobile = Rails.root.join("docs/menu-mobile.html").read
    admin = Rails.root.join("docs/admin.html").read

    [desktop, mobile, admin].each do |source|
      assert_includes source, "prefers-reduced-motion"
      assert_includes source, ":focus-visible"
    end

    assert_includes desktop, "class=\"skeleton\""
    assert_includes desktop, "aria-busy"
    assert_includes desktop, ".product-media,.product-media img{width:132px;height:132px}"
    assert_includes desktop, ".product-media img{object-fit:cover}"
    assert_includes mobile, "ui-shimmer"
    assert_includes mobile, "aria-busy"
    assert_includes mobile, ".product-media { align-self: center; width: 150px; height: 120px;"
    assert_includes mobile, ".product-media img { display: block; width: 150px; height: 120px;"
    assert_includes admin, "toast-enter-active"
    assert_includes admin, "ui-panel"
  end

  test "clientes empacotados usam Lineicons" do
    %w[docs/menu.html docs/menu-mobile.html docs/pagina-inicial.html docs/admin.html].each do |path|
      source = Rails.root.join(path).read

      assert_includes source, "cdn.lineicons.com/5.0/lineicons.css", path
      assert_not_includes source, "font-awesome", path
      assert_not_includes source, "material-symbols", path
    end
  end

  test "clientes empacotados suportam informações configuráveis do restaurante" do
    desktop = Rails.root.join("docs/menu.html").read
    mobile = Rails.root.join("docs/menu-mobile.html").read
    admin = Rails.root.join("docs/admin.html").read

    [desktop, mobile].each do |source|
      assert_includes source, "menu_information"
      assert_includes source, "noopener noreferrer"
    end
    assert_includes mobile, "restaurant-delivery"
    assert_includes mobile, "restaurant-status"
    assert_includes mobile, "restaurant-delivery-estimate"
    assert_includes mobile, "restaurant-meta"
    assert_includes mobile, "restaurant-actions"
    assert_includes mobile, "restaurant-information-divider"
    assert_includes mobile, "lni-bike"
    assert_includes mobile, "lni-dollar"
    assert_includes mobile, "lni-phone"
    assert_includes mobile, "Ver mapa"
    assert_includes mobile, "lni-map-marker-1"
    assert_not_includes mobile, "restaurant-address-row"
    assert_not_includes mobile, "restaurant-location"
    assert_includes mobile, "aria-hidden=\"true\""
    assert_includes desktop, "restaurant-meta"
    assert_includes desktop, "restaurant-actions"
    assert_includes desktop, "restaurant-summary"
    assert_includes desktop, "restaurant-summary-meta"
    assert_includes desktop, "restaurant-summary-actions"
    assert_includes desktop, "restaurant-logo"
    assert_includes desktop, "restaurant.logo_url"
    assert_includes desktop, "var(--accent)"
    assert_includes desktop, "Ver mapa"
    assert_includes desktop, "lni-map-marker-1"
    assert_not_includes desktop, "restaurant-address-row"
    assert_not_includes desktop, "restaurant-location"
    assert_includes admin, "Informações exibidas no cardápio"
    assert_includes admin, "menu_information.visibility"
    assert_includes admin, "newProductForm.image_file"
    assert_includes admin, "editProductForm.image_file"
    assert_includes admin, "productMutationBody"
    assert_includes admin, '`${key}[]`'
    assert_not_includes admin, '`${key}[${index}]`'
    assert_includes admin, "image/png,image/jpeg,image/webp"
  end
end
