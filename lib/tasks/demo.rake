namespace :demo do
  desc "Create or update local demonstration restaurants and tenant users"
  task seed: :environment do
    load Rails.root.join("db/seeds/default_restaurant.rb")
    load Rails.root.join("db/seeds/test_burger_restaurant.rb")
    puts "Demo restaurants ready."
  end

  desc "Reset only the known local demonstration restaurants, then recreate them"
  task reset: :environment do
    %w[forno-e-massa burger-lab].each do |slug|
      restaurant = Restaurant.find_by(slug: slug)
      next unless restaurant

      restaurant.orders.destroy_all
      restaurant.users.delete_all
      restaurant.products.destroy_all
      restaurant.categories.destroy_all
      restaurant.destroy!
    end
    Rake::Task["demo:seed"].reenable
    Rake::Task["demo:seed"].invoke
  end
end
