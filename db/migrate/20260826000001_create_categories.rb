class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :categories, "lower(name)", unique: true
  end
end
