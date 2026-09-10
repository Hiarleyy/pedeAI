# Hamburgueria de demonstracao para desenvolvimento e homologacao.
# Execute isoladamente com:
#   bin/rails runner db/seeds/test_burger_restaurant.rb

restaurant = Restaurant.find_or_initialize_by(slug: "burger-lab")
restaurant.assign_attributes(
  name: "Burger Lab",
  menu_description: "Hamburgueres artesanais, acompanhamentos e bebidas.",
  primary_color: "#f59e0b",
  font_family: "inter",
  menu_information: {
    "tagline" => "Hamburguer artesanal feito na hora",
    "status" => "open",
    "delivery_estimate" => "35 min",
    "delivery_fee" => 6.0,
    "map_url" => "https://maps.google.com/?q=Burger+Lab"
  }
)
restaurant.save!

category_definitions = [
  ["Hamburgueres", "Hamburgueres artesanais da casa"],
  ["Combos", "Combos completos com acompanhamento e bebida"],
  ["Acompanhamentos", "Porcoes para acompanhar seu pedido"],
  ["Bebidas", "Bebidas geladas"]
]

categories = category_definitions.each_with_index.to_h do |(name, description), position|
  category = Category.find_or_initialize_by(restaurant: restaurant, name: name)
  category.assign_attributes(description: description, position: position)
  category.save!
  [name, category]
end

products = [
  ["Classic Burger", "Pao brioche, carne de 160 g, queijo, alface, tomate e molho da casa", 27.90, "Hamburgueres"],
  ["Bacon Supreme", "Pao brioche, carne de 180 g, cheddar, bacon crocante e cebola caramelizada", 34.90, "Hamburgueres"],
  ["Chicken Crispy", "Frango empanado, queijo, alface, tomate e maionese especial", 29.90, "Hamburgueres"],
  ["Veggie Burger", "Burger vegetal, queijo, alface, tomate, cebola roxa e molho especial", 30.90, "Hamburgueres"],
  ["Combo Classic", "Classic Burger, batata frita individual e refrigerante lata", 39.90, "Combos"],
  ["Combo Bacon", "Bacon Supreme, batata frita individual e refrigerante lata", 46.90, "Combos"],
  ["Batata Frita", "Batatas fritas crocantes com sal e tempero da casa", 14.90, "Acompanhamentos"],
  ["Onion Rings", "Aneis de cebola empanados e molho barbecue", 18.90, "Acompanhamentos"],
  ["Refrigerante Lata", "Refrigerante gelado, lata de 350 ml", 6.50, "Bebidas"],
  ["Limonada Artesanal", "Limonada natural de 500 ml", 9.90, "Bebidas"]
]

products.each do |name, description, price, category_name|
  product = Product.find_or_initialize_by(restaurant: restaurant, name: name)
  product.assign_attributes(
    category: categories.fetch(category_name),
    description: description,
    price: price,
    available: true
  )
  product.save!
end

admin_email = ENV.fetch("BURGER_LAB_ADMIN_EMAIL", "admin@burger-lab.pedeai.test")
admin_password = ENV.fetch("BURGER_LAB_ADMIN_PASSWORD", "admin123")
admin = User.find_or_initialize_by(email: admin_email)
admin.assign_attributes(
  name: "Administrador Burger Lab",
  role: "superAdmin",
  restaurant: restaurant,
  permissions: {}
)
if admin.new_record? || ENV.key?("BURGER_LAB_ADMIN_PASSWORD")
  admin.password = admin_password
  admin.password_confirmation = admin_password
end
admin.save!

puts "Hamburgueria criada/atualizada: #{restaurant.slug}"
puts "Categorias do seed: #{category_definitions.length} | Produtos do seed: #{products.length}"
puts "Admin: #{admin.email}"
