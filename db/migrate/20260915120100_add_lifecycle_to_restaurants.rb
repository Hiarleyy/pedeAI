class AddLifecycleToRestaurants < ActiveRecord::Migration[8.1]
  def change
    add_column :restaurants, :status, :string, null: false, default: "active"
    add_column :restaurants, :suspension_reason, :text
    add_column :restaurants, :suspended_at, :datetime
    add_column :restaurants, :last_access_at, :datetime
    add_index :restaurants, :status
    add_check_constraint :restaurants, "status IN ('active', 'suspended')", name: "restaurants_status_check"
  end
end
