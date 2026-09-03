class EnforceOneSuperAdminPerRestaurant < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE users
      SET role = 'funcionario', permissions = '{}'::jsonb
      WHERE role = 'superAdmin' AND restaurant_id IS NULL
    SQL

    add_index :users, :restaurant_id,
              unique: true,
              where: "role = 'superAdmin'",
              name: "index_users_on_one_super_admin_per_restaurant"
  end

  def down
    remove_index :users, name: "index_users_on_one_super_admin_per_restaurant"
  end
end
