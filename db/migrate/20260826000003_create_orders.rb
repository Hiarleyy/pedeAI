class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :customer_name, null: false
      t.string :customer_phone, null: false
      t.string :order_type, null: false
      t.string :delivery_address
      t.string :table_number
      t.string :payment_method, null: false
      t.string :status, null: false, default: "pending"
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :orders, :status
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.timestamps
    end
  end
end
