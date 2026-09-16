class CreatePlatformUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "read_only"
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.timestamps
    end

    add_index :platform_users, "lower(email)", unique: true, name: "index_platform_users_on_lower_email"
    add_index :platform_users, :role
  end
end
