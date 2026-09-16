require "test_helper"

class Api::V1::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Pedidos", menu_information: always_open_information)
    category = Category.create!(restaurant: @restaurant, name: "Lanches")
    @product = Product.create!(restaurant: @restaurant, category: category, name: "Burger", price: 25.0)
    @cheese = @product.addons.create!(name: "Queijo extra", price: 4.5)
    @egg = @product.addons.create!(name: "Ovo", price: 3)
    @inactive_addon = @product.addons.create!(name: "Bacon indisponível", price: 6, available: false)
    @unavailable = Product.create!(restaurant: @restaurant, category: category, name: "Burger esgotado", price: 30.0, available: false)
    @other_restaurant = Restaurant.create!(name: "Outro Restaurante de Pedidos", menu_information: always_open_information)
    other_category = Category.create!(restaurant: @other_restaurant, name: "Outros Lanches")
    @other_product = Product.create!(restaurant: @other_restaurant, category: other_category, name: "Burger alheio", price: 100.0)
    @foreign_addon = @other_product.addons.create!(name: "Molho alheio", price: 3)
  end

  test "rejeita pedido sem campos obrigatorios" do
    post orders_path, params: { order: { customer_name: "A", order_type: "delivery", payment_method: "pix", items: [] } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_error", response.parsed_body["error"]
  end

  test "cria pedido delivery e retorna total" do
    post orders_path, params: { order: { customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix", items: [{ product_id: @product.id, quantity: 2 }] } }, as: :json
    assert_response :created
    assert_equal "50.0", response.parsed_body["total"].to_s
  end

  test "cria pedido presencial identificando a mesa" do
    post orders_path, params: { order: { customer_name: "Bruno", customer_phone: "11988888888", order_type: "dine_in", table_number: "12", payment_method: "card", items: [{ product_id: @product.id, quantity: 1 }] } }, as: :json
    assert_response :created
    assert_equal "12", response.parsed_body["table_number"]
    assert_equal "Mesa 12", response.parsed_body["table_label"]
  end

  test "rejeita pedido quando restaurante esta fechado sem persistir o agregado" do
    @restaurant.update!(menu_information: schedule_information("1" => [{ "open" => "10:00", "close" => "12:00", "enabled" => true }]))

    travel_to ActiveSupport::TimeZone["America/Sao_Paulo"].parse("2026-09-07 09:00:00") do
      assert_no_difference ["Order.count", "OrderItem.count"] do
        post orders_path, params: order_payload(@product), as: :json
      end
    end

    assert_response :conflict
    assert_equal "restaurant_closed", response.parsed_body["error"]
    assert_equal "10:00", response.parsed_body["next_opening"]
    assert_includes response.parsed_body.fetch("messages").first, "Restaurante fechado"
  end

  test "rejeita pedido quando restaurante nao possui horarios configurados" do
    @restaurant.update!(menu_information: schedule_information({}))

    assert_no_difference ["Order.count", "OrderItem.count"] do
      post orders_path, params: order_payload(@product), as: :json
    end

    assert_response :conflict
    assert_equal({ "error" => "restaurant_closed", "messages" => ["Restaurante fechado no momento."], "next_opening" => nil }, response.parsed_body)
  end

  test "mantem rastreamento disponivel quando restaurante esta fechado" do
    order = create_tracked_order
    @restaurant.update!(menu_information: schedule_information({}))

    get track_orders_path, params: { query: "##{order.id}" }

    assert_response :success
    assert_equal order.id, response.parsed_body["id"]
  end

  test "mantem a listagem de pedidos restrita a administradores" do
    get orders_path

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "rejeita produto indisponível sem persistir o agregado" do
    assert_no_difference ["Order.count", "OrderItem.count"] do
      post orders_path, params: order_payload(@unavailable), as: :json
    end

    assert_response :not_found
    assert_equal "resource_not_found", response.parsed_body["error"]
  end

  test "rejeita produto de outro restaurante sem persistir o agregado" do
    assert_no_difference ["Order.count", "OrderItem.count"] do
      post orders_path, params: order_payload(@other_product), as: :json
    end

    assert_response :not_found
  end

  test "ignora preço enviado pelo cliente e usa preço persistido" do
    payload = order_payload(@product)
    payload[:order][:items].first[:unit_price] = 0.01

    post orders_path, params: payload, as: :json

    assert_response :created
    assert_equal "25.0", response.parsed_body["total"].to_s
    assert_equal 25.to_d, OrderItem.last.unit_price
  end

  test "calcula adicionais no servidor e salva seus snapshots" do
    payload = order_payload(@product)
    payload[:order][:items].first[:addon_ids] = [@cheese.id]
    payload[:order][:items].first[:addon_price] = 0.01

    post orders_path, params: payload, as: :json

    assert_response :created
    assert_equal "29.5", response.parsed_body["total"].to_s
    item = response.parsed_body.fetch("order_items").first
    assert_equal "29.5", item["unit_price"].to_s
    assert_equal [{ "name" => "Queijo extra", "price" => "4.5" }], item.fetch("addons").map { |addon| addon.slice("name", "price") }
  end

  test "calcula variação absoluta, múltiplos adicionais e quantidade no servidor" do
    variant = @product.variants.create!(name: "Duplo", price: 32.9)
    payload = order_payload(@product)
    item = payload[:order][:items].first
    item.merge!(variant_id: variant.id, addon_ids: [@cheese.id, @egg.id], quantity: 2, unit_price: 0.01, addon_price: 0.01)

    post orders_path, params: payload, as: :json

    assert_response :created
    assert_equal "80.8", response.parsed_body["total"].to_s
    persisted = OrderItem.last
    assert_equal 40.4.to_d, persisted.unit_price
    assert_equal 32.9.to_d, persisted.variant_price
    assert_equal [3.to_d, 4.5.to_d], persisted.addons.map(&:price).sort
  end

  test "rejeita adicional inativo, duplicado ou de outro produto sem persistir" do
    [ [@inactive_addon.id], [@cheese.id, @cheese.id], [@foreign_addon.id] ].each do |addon_ids|
      assert_no_difference ["Order.count", "OrderItem.count", "OrderItemAddon.count"] do
        payload = order_payload(@product)
        payload[:order][:items].first[:addon_ids] = addon_ids
        post orders_path, params: payload, as: :json
      end

      assert_response :unprocessable_entity
      assert_equal "validation_error", response.parsed_body["error"]
    end
  end

  test "pedido mantém o preço do adicional após alteração da configuração" do
    payload = order_payload(@product)
    payload[:order][:items].first[:addon_ids] = [@cheese.id]
    post orders_path, params: payload, as: :json
    assert_response :created

    @cheese.update!(name: "Queijo premium", price: 8)
    order_item = OrderItem.last.reload
    assert_equal 29.5.to_d, order_item.unit_price
    assert_equal "Queijo extra", order_item.addons.first.name
    assert_equal 4.5.to_d, order_item.addons.first.price
  end

  test "pedido inválido não persiste pedido nem itens" do
    assert_no_difference ["Order.count", "OrderItem.count"] do
      post orders_path, params: { order: { customer_name: "A", customer_phone: "x", order_type: "delivery", payment_method: "pix", items: [{ product_id: @product.id, quantity: 1 }] } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "validation_error", response.parsed_body["error"]
  end

  test "rastreia publicamente pedido por numero sem expor dados sensiveis" do
    order = create_tracked_order(status: "preparing")

    get track_orders_path, params: { query: "##{order.id}" }

    assert_response :success
    assert_equal({ "id" => order.id, "status" => "preparing", "order_type" => "delivery" }, response.parsed_body.slice("id", "status", "order_type"))
    %w[customer_name customer_phone delivery_address payment_method order_items total].each { |key| assert_not_includes response.parsed_body, key }
  end

  test "rastreia telefone normalizado e prioriza pedido em andamento" do
    delivered = create_tracked_order(status: "delivered", phone: "(11) 99999-9999")
    preparing = create_tracked_order(status: "preparing", phone: "11999999999")

    get track_orders_path, params: { query: "+55 (11) 99999-9999" }

    assert_response :success
    assert_equal preparing.id, response.parsed_body["id"]
    assert_not_equal delivered.id, response.parsed_body["id"]
  end

  test "nao revela pedidos de outro restaurante nem aceita busca invalida" do
    foreign_order = create_tracked_order(restaurant: @other_restaurant, product: @other_product)

    get track_orders_path, params: { query: "##{foreign_order.id}" }
    assert_response :not_found
    assert_equal "order_not_found", response.parsed_body["error"]

    get track_orders_path, params: { query: "sem pedido" }
    assert_response :unprocessable_entity
    assert_equal "tracking_query_invalid", response.parsed_body["error"]
  end

  test "responde limite temporario sem expor a busca" do
    ip = "198.51.100.#{Process.pid % 200 + 1}"
    rate_key = "order-tracking:#{@restaurant.slug}:#{ip}"
    Rails.cache.delete(rate_key)

    OrderTrackingRateLimiter.limit.times do
      get track_orders_path, params: { query: "123" }, headers: { "REMOTE_ADDR" => ip }
      assert_response :not_found
    end

    get track_orders_path, params: { query: "123" }, headers: { "REMOTE_ADDR" => ip }

    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body["error"]
  end

  private

  def always_open_information
    schedule_information((0..6).index_with { [{ "open" => "00:00", "close" => "00:00", "enabled" => true }] })
  end

  def schedule_information(hours)
    {
      "timezone" => "America/Sao_Paulo",
      "hours" => hours.transform_keys(&:to_s),
      "visibility" => { "operating" => true, "delivery" => false, "location" => false, "contact" => false, "social" => false }
    }
  end

  def orders_path = "/api/v1/restaurants/#{@restaurant.slug}/orders"
  def track_orders_path = "/api/v1/restaurants/#{@restaurant.slug}/orders/track"

  def order_payload(product)
    { order: { customer_name: "Ana", customer_phone: "11999999999", order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix", items: [{ product_id: product.id, quantity: 1 }] } }
  end

  def create_tracked_order(restaurant: @restaurant, product: @product, status: "pending", phone: "11999999999")
    order = Order.new(restaurant: restaurant, customer_name: "Cliente", customer_phone: phone, order_type: "delivery", delivery_address: "Rua A, 1", payment_method: "pix", status: status)
    order.order_items.build(product: product, quantity: 1, unit_price: product.price)
    order.save!
    order
  end
end
