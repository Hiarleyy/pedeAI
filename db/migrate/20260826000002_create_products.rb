class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :available, null: false, default: true
      t.string :image_url
      t.timestamps
    end
    add_index :products, :available
  end
end
