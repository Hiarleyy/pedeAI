class AddProductPlaceholderToRestaurants < ActiveRecord::Migration[8.1]
  def change
    add_column :restaurants, :product_placeholder_url, :text
  end
end
