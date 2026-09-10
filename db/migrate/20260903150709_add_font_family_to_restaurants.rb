class AddFontFamilyToRestaurants < ActiveRecord::Migration[8.1]
  def change
    add_column :restaurants, :font_family, :string, default: 'inter', null: false
  end
end

