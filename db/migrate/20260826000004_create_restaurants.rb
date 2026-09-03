class CreateRestaurants < ActiveRecord::Migration[8.1]
  def change
    create_table :restaurants do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :restaurants, :slug, unique: true
  end
end
