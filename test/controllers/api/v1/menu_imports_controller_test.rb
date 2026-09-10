require "test_helper"
require "tempfile"

class Api::V1::MenuImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Restaurante Importador")
    @owner = User.create!(restaurant: @restaurant, name: "Dono", email: "dono-importador@example.com", password: "secret123", role: "superAdmin")
    @category = @restaurant.categories.create!(name: "Bebidas")
  end

  test "importa categorias, produtos, adicionais e variacoes sem imagens" do
    payload = menu_payload(categories: [
      { name: "Bebidas", products: [{ name: "Suco natural", price: 12.5, addons: [{ name: "Gelo", price: 1 }], variants: [{ name: "500ml", price: 12.5, position: 0 }] }] },
      { name: "Lanches", description: "Artesanais", position: 2, products: [{ name: "X-Salada", price: 25, available: false }] }
    ])

    assert_difference({ "Category.count" => 1, "Product.count" => 2, "ProductAddon.count" => 1, "ProductVariant.count" => 1 }) do
      import(payload, headers: auth)
    end

    assert_response :created
    assert_equal({ "categories_created" => 1, "products_created" => 2 }, response.parsed_body)
    product = @restaurant.products.find_by!(name: "Suco natural")
    assert_equal @category, product.category
    assert_nil product.image_url
    assert_equal ["Gelo"], product.addons.pluck(:name)
    assert_equal ["500ml"], product.variants.pluck(:name)
  end

  test "produto importado recebe imagem multipart e preserva todos os dados editáveis" do
    payload = menu_payload(categories: [{
      name: "Lanches",
      products: [{
        name: "X-Importado",
        description: "Receita da casa",
        price: 25.9,
        addons: [{ name: "Bacon", price: 4 }],
        variants: [{ name: "Duplo", price: 32.9, position: 0 }]
      }]
    }])
    import(payload, headers: auth)
    assert_response :created

    product = @restaurant.products.includes(:addons, :variants).find_by!(name: "X-Importado")
    addon = product.addons.first
    variant = product.variants.first
    patch "/api/v1/restaurants/#{@restaurant.slug}/products/#{product.id}", params: { product: {
      category_id: product.category_id,
      name: product.name,
      description: product.description,
      price: product.price.to_s,
      available: product.available,
      image: uploaded_png,
      addons: [{ id: addon.id, name: addon.name, price: addon.price.to_s, available: addon.available }],
      variants: [{ id: variant.id, name: variant.name, price: variant.price.to_s, available: variant.available, position: variant.position }]
    } }, headers: auth

    assert_response :success
    stored_url = response.parsed_body.fetch("image_url")
    product.reload
    assert_equal "X-Importado", product.name
    assert_equal "Receita da casa", product.description
    assert_equal 25.9.to_d, product.price
    assert_equal ["Bacon"], product.addons.pluck(:name)
    assert_equal ["Duplo"], product.variants.pluck(:name)
    assert_equal stored_url, product.image_url
    assert Rails.root.join("public", stored_url.delete_prefix("/")).exist?
  ensure
    ProductImageStorage.new.delete_url!(stored_url) if defined?(stored_url) && stored_url
  end

  test "rejeita campos de imagem e preserva todos os dados" do
    existing = @restaurant.products.create!(category: @category, name: "Produto existente", price: 10, image_url: "https://example.test/existente.png")
    payload = menu_payload(categories: [{ name: "Lanches", products: [{ name: "Novo produto", price: 15, image_url: "https://example.test/novo.png" }] }])

    assert_no_difference ["Category.count", "Product.count"] do
      import(payload, headers: auth)
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages").join(" "), "image_url não é aceito"
    assert_equal "https://example.test/existente.png", existing.reload.image_url
  end

  test "rejeita produto duplicado e nao deixa importacao parcial" do
    @restaurant.products.create!(category: @category, name: "Suco", price: 10)
    payload = menu_payload(categories: [{ name: "Lanches", products: [{ name: "Novo", price: 15 }, { name: "suco", price: 12 }] }])

    assert_no_difference ["Category.count", "Product.count"] do
      import(payload, headers: auth)
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages").join(" "), "Já existe um produto"
  end

  test "rejeita arquivo JSON invalido" do
    import("{invalido", headers: auth)

    assert_response :unprocessable_entity
    assert_equal ["Arquivo JSON inválido"], response.parsed_body.fetch("messages")
  end

  test "rejeita versao desconhecida, campos internos e preco invalido" do
    payload = JSON.generate(version: 2, categories: [{ name: "Lanches", id: 9, products: [{ name: "Novo", price: 0 }] }])

    assert_no_difference ["Category.count", "Product.count"] do
      import(payload, headers: auth)
    end

    assert_response :unprocessable_entity
    messages = response.parsed_body.fetch("messages").join(" ")
    assert_includes messages, "version deve ser 1"
    assert_includes messages, "categories[0].id não é aceito"
    assert_includes messages, "price deve ser maior que zero"
  end

  test "rejeita texto com codificação corrompida" do
    payload = menu_payload(categories: [{ name: "Bebidas", products: [{ name: "Suco de Maracuj\u00C3\u00A1", price: 12 }] }])

    assert_no_difference "Product.count" do
      import(payload, headers: auth)
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("messages").join, "codificação corrompida"
  end

  test "exige ambas as permissoes de escrita" do
    employee = User.create!(restaurant: @restaurant, name: "Equipe", email: "equipe-importador@example.com", password: "secret123", role: "funcionario", permissions: { "products:write" => true })

    assert_no_difference ["Category.count", "Product.count"] do
      import(menu_payload, headers: auth(employee))
    end

    assert_response :forbidden
    assert_equal "categories:write", response.parsed_body.fetch("permission")
  end

  test "exige autenticacao" do
    assert_no_difference ["Category.count", "Product.count"] do
      import(menu_payload, headers: {})
    end

    assert_response :unauthorized
  end

  test "nao permite importar no restaurante de outro usuario" do
    other = Restaurant.create!(name: "Outro restaurante")

    assert_no_difference ["Category.count", "Product.count"] do
      import(menu_payload, headers: auth, restaurant: other)
    end

    assert_response :not_found
  end

  test "disponibiliza modelo JSON sem campos de imagem" do
    get "/menu-import-template.json"

    assert_response :success
    template = JSON.parse(response.body)
    assert_equal 1, template.fetch("version")
    assert template.fetch("categories").any?
    refute_includes response.body, "image"
  end

  private

  def menu_payload(categories: [{ name: "Lanches", products: [{ name: "Hambúrguer", price: 20 }] }])
    JSON.generate(version: 1, categories: categories)
  end

  def import(content, headers:, restaurant: @restaurant)
    file = Tempfile.new(["cardapio", ".json"])
    file.write(content)
    file.rewind
    post "/api/v1/restaurants/#{restaurant.slug}/menu-import", params: { file: Rack::Test::UploadedFile.new(file.path, "application/json") }, headers: headers
  ensure
    file&.close!
  end

  def auth(user = @owner) = { "Authorization" => "Bearer #{user.api_token}" }
end
