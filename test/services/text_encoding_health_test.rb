require "test_helper"

class TextEncodingHealthTest < ActiveSupport::TestCase
  test "identifica substituição e mojibake sem rejeitar texto UTF-8 válido" do
    refute TextEncodingHealth.suspicious?("Pão, maçã e café")
    assert TextEncodingHealth.suspicious?("Maracuj\u00C3\u00A1")
    assert TextEncodingHealth.suspicious?("Texto com \uFFFD")
  end

  test "informa o caminho de valores suspeitos em estruturas aninhadas" do
    value = { "location" => { "address" => "Rua com \uFFFD" } }

    assert_equal ["menu_information.location.address"], TextEncodingHealth.suspicious_paths(value, "menu_information")
  end

  test "modelos bloqueiam campos com codificação suspeita" do
    restaurant = Restaurant.create!(name: "Restaurante Limpo")
    category = restaurant.categories.create!(name: "Bebidas")
    product = restaurant.products.build(category: category, name: "Suco de Maracuj\u00C3\u00A1", price: 12)

    assert_not product.valid?
    assert_includes product.errors[:name].join, "codificação corrompida"
  end

  test "configuração aninhada do restaurante bloqueia texto suspeito" do
    restaurant = Restaurant.new(name: "Restaurante Limpo", menu_information: {
      "location" => { "address" => "Rua com \uFFFD" }
    })

    assert_not restaurant.valid?
    assert_includes restaurant.errors[:menu_information].join, "location.address"
  end

  test "auditoria localiza registros legados sem expor o conteúdo" do
    restaurant = Restaurant.create!(name: "Restaurante Auditoria")
    category = restaurant.categories.create!(name: "Bebidas")
    product = restaurant.products.create!(category: category, name: "Suco", price: 12)
    product.update_columns(name: "Suco de Maracuj\u00C3\u00A1", description: "Suco natural de maracuj\u00C3\u00A1")

    findings = TextEncodingAudit.new.findings.select { |finding| finding.model == "Product" && finding.id == product.id }

    assert_equal %i[description name], findings.map(&:attribute).sort
    assert findings.all? { |finding| finding.paths.any? }
  end

  test "reparo conhecido exige a combinação exata e normaliza o produto legado" do
    restaurant = Restaurant.create!(name: "Restaurante Reparo")
    category = restaurant.categories.create!(name: "Bebidas")
    product = restaurant.products.create!(category: category, name: "Suco", price: 12)
    product.update_columns(name: TextEncodingAudit::LEGACY_PRODUCT_NAME, description: TextEncodingAudit::LEGACY_PRODUCT_DESCRIPTION)

    assert_equal 1, TextEncodingAudit.new.repair_known!
    assert_equal TextEncodingAudit::REPAIRED_PRODUCT_NAME, product.reload.name
    assert_equal TextEncodingAudit::REPAIRED_PRODUCT_DESCRIPTION, product.description
  end

  test "arquivos de código e telas não contêm sequências corrompidas" do
    source_roots = %w[app config docs lib test]
    extensions = %w[.rb .html .json .md .rake .yaml .yml]
    files = source_roots.flat_map do |root|
      Dir.glob(Rails.root.join(root, "**", "*"), File::FNM_DOTMATCH)
    end.select { |path| File.file?(path) && extensions.include?(File.extname(path)) }

    findings = files.flat_map do |path|
      paths = TextEncodingHealth.suspicious_paths(File.read(path), path.to_s.delete_prefix("#{Rails.root}/"))
      paths.map { |suspect| "#{path}: #{suspect}" }
    end

    assert_empty findings, findings.join("\n")
  end
end
