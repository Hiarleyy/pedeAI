class CreateProductAddonsAndOrderItemAddons < ActiveRecord::Migration[8.1]
  def change
    create_table :product_addons do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :available, null: false, default: true
      t.timestamps
    end
    add_index :product_addons, [:product_id, :name], unique: true
    add_index :product_addons, :available

    create_table :order_item_addons do |t|
      t.references :order_item, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.timestamps
    end
  end
end
