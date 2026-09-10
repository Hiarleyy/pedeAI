# Dados básicos para desenvolvimento e demonstração no navegador.
# Execute com: bin/rails db:seed

restaurants = [
  { name: "Forno & Massa", slug: "forno-e-massa" },
  { name: "Casa do Sabor", slug: "casa-do-sabor" }
]

restaurants.each do |attributes|
  restaurant = Restaurant.find_or_create_by!(slug: attributes[:slug]) do |r|
    r.name = attributes[:name]
  end

category_descriptions = {
    "Entradas" => "Petiscos e entradas da casa",
    "Pratos principais" => "Pratos preparados na hora",
    "Bebidas" => "Bebidas geladas"
  }
  categories = category_descriptions.to_h do |name, description|
    [name, Category.find_or_create_by!(restaurant: restaurant, name: name) do |category|
      category.description = description
    end]
  end
  if restaurant.slug == "forno-e-massa"
    products = [
      ["Bruschetta Tradicional", "Pão italiano, tomate, manjericão e azeite", 24.90, "Entradas"],
      ["Margherita", "Molho de tomate, mussarela e manjericão fresco", 39.90, "Pratos principais"],
      ["Calabresa", "Calabresa, cebola e mussarela", 42.90, "Pratos principais"],
      ["Limonada da Casa", "Limonada natural com hortelã", 9.90, "Bebidas"]
    ]
  else
    products = [
      ["Pastel da Casa", "Pastel crocante com recheio artesanal", 14.90, "Entradas"],
      ["Arroz de Costela", "Costela desfiada, arroz e acompanhamentos", 39.90, "Pratos principais"],
      ["Frango Caipira", "Frango ao molho com arroz e farofa", 34.90, "Pratos principais"],
      ["Suco de Maracujá", "Suco natural de maracujá", 8.90, "Bebidas"]
    ]
  end

  products.each do |name, description, price, category_name|
    Product.find_or_create_by!(restaurant: restaurant, name: name) do |product|
      product.category = categories.fetch(category_name)
      product.description = description
      product.price = price
      product.available = true
    end
  end

  User.find_or_create_by!(email: "superadmin@#{restaurant.slug}.pedeai.test") do |user|
    user.name = "SuperAdmin #{restaurant.name}"
    user.password = "admin123"
    user.password_confirmation = "admin123"
    user.role = "superAdmin"
    user.restaurant = restaurant
  end
  User.find_or_create_by!(email: "admin@#{restaurant.slug}.pedeai.test") do |user|
    user.name = "Admin #{restaurant.name}"
    user.password = "admin123"
    user.password_confirmation = "admin123"
    user.role = "admin"
    user.restaurant = restaurant
  end

  User.find_or_create_by!(email: "funcionario@#{restaurant.slug}.pedeai.test") do |user|
    user.name = "Funcionário #{restaurant.name}"
    user.password = "func123"
    user.password_confirmation = "func123"
    user.role = "funcionario"
    user.permissions = { "orders:read" => true, "orders:update" => true, "products:read" => true }
    user.restaurant = restaurant
  end
end

puts "Seed concluído."
puts "Forno & Massa: /cardapio/forno-e-massa e /admin/forno-e-massa"
puts "  SuperAdmin: superadmin@forno-e-massa.pedeai.test / admin123"
puts "Casa do Sabor: /cardapio/casa-do-sabor e /admin/casa-do-sabor"
puts "  SuperAdmin: superadmin@casa-do-sabor.pedeai.test / admin123"

load Rails.root.join("db/seeds/test_burger_restaurant.rb")
