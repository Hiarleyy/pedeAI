# Popula uma instalação limpa com o restaurante padrão usado na demonstração.
# Execute com: bin/rails runner db/seeds/default_restaurant.rb

restaurant = Restaurant.find_or_initialize_by(slug: "forno-e-massa")
restaurant.assign_attributes(
  name: "Forno & Massa",
  menu_description: "Massas artesanais, pizzas e sobremesas feitas na casa.",
  primary_color: "#d34000",
  font_family: "inter",
  menu_information: {
    "tagline" => "Massas artesanais e pizzas caseiras",
    "status" => "open",
    "delivery_estimate" => "45 min",
    "delivery_fee" => 10.0,
    "map_url" => "https://maps.google.com/?q=Forno+e+Massa"
  }
)
restaurant.save!

categories = {
  "Entradas" => "Petiscos e entradas da casa",
  "Pizzas" => "Pizzas artesanais com massa de fermentação natural",
  "Massas" => "Massas preparadas na hora",
  "Bebidas" => "Bebidas geladas e sucos naturais",
  "Sobremesas" => "Doces para finalizar a refeição"
}.each_with_index.to_h do |(name, description), position|
  category = Category.find_or_initialize_by(restaurant: restaurant, name: name)
  category.assign_attributes(description: description, position: position)
  category.save!
  [name, category]
end

[
  ["Bruschetta Tradicional", "Pão italiano, tomate, manjericão e azeite", 24.90, "Entradas"],
  ["Margherita", "Molho de tomate, mussarela e manjericão fresco", 39.90, "Pizzas"],
  ["Calabresa", "Calabresa, cebola e mussarela", 42.90, "Pizzas"],
  ["Quatro Queijos", "Mussarela, provolone, parmesão e gorgonzola", 47.90, "Pizzas"],
  ["Lasanha Bolonhesa", "Massa fresca, molho bolonhesa e queijo gratinado", 38.90, "Massas"],
  ["Fettuccine Alfredo", "Fettuccine ao molho cremoso de parmesão", 34.90, "Massas"],
  ["Limonada da Casa", "Limonada natural com hortelã", 9.90, "Bebidas"],
  ["Refrigerante Lata", "Lata de 350 ml", 6.50, "Bebidas"],
  ["Tiramisù", "Creme de mascarpone, café e cacau", 18.90, "Sobremesas"]
].each do |name, description, price, category_name|
  product = Product.find_or_initialize_by(restaurant: restaurant, name: name)
  product.assign_attributes(category: categories.fetch(category_name), description: description, price: price, available: true)
  product.save!
end

margherita = Product.find_by!(restaurant: restaurant, name: "Margherita")
ProductVariant.find_or_create_by!(product: margherita, name: "Grande") do |variant|
  variant.price = 49.90
  variant.position = 0
  variant.available = true
end
ProductAddon.find_or_create_by!(product: margherita, name: "Borda recheada") do |addon|
  addon.price = 8.00
  addon.available = true
end

[
  ["superadmin@forno-e-massa.pedeai.test", "SuperAdmin Forno & Massa", "superAdmin", {}],
  ["admin@forno-e-massa.pedeai.test", "Administrador Forno & Massa", "admin", {}],
  ["funcionario@forno-e-massa.pedeai.test", "Atendente Forno & Massa", "funcionario", { "orders:read" => true, "orders:update" => true, "products:read" => true }]
].each do |email, name, role, permissions|
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(name: name, role: role, restaurant: restaurant, permissions: permissions)
  if user.new_record?
    user.password = role == "funcionario" ? "func123" : "admin123"
    user.password_confirmation = user.password
  end
  user.save!
end

puts "Restaurante padrão criado/atualizado: #{restaurant.slug}"
puts "Produtos: #{restaurant.products.count} | Categorias: #{restaurant.categories.count}"
