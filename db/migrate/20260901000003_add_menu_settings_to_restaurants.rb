class AddMenuSettingsToRestaurants < ActiveRecord::Migration[8.1]
  def change
    add_column :restaurants, :menu_description, :text
    add_column :restaurants, :banner_url, :text
    add_column :restaurants, :logo_url, :text
    add_column :restaurants, :primary_color, :string, null: false, default: "#d34000"
  end
end
