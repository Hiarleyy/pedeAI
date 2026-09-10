class CreateProductVariantsAndAddOrderItemCustomizations < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.boolean :available, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :product_variants, [:product_id, :name], unique: true
    add_column :order_items, :variant_name, :string
    add_column :order_items, :variant_price, :decimal, precision: 10, scale: 2
    add_column :order_items, :note, :text
  end
end
