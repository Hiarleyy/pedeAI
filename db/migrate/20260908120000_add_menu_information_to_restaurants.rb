class AddMenuInformationToRestaurants < ActiveRecord::Migration[8.1]
  def change
    add_column :restaurants, :menu_information, :jsonb, null: false, default: {}
  end
end
