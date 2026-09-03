class RepairRestaurantScopedResources < ActiveRecord::Migration[8.1]
  def up
    remove_index :categories, name: "index_categories_on_lower_name"

    fallback_restaurant_id = select_value("SELECT id FROM restaurants ORDER BY id LIMIT 1")
    orphan_count = select_value(<<~SQL).to_i
      SELECT
        (SELECT COUNT(*) FROM categories WHERE restaurant_id IS NULL) +
        (SELECT COUNT(*) FROM products WHERE restaurant_id IS NULL) +
        (SELECT COUNT(*) FROM orders WHERE restaurant_id IS NULL)
    SQL

    if orphan_count.positive? && fallback_restaurant_id.nil?
      raise ActiveRecord::MigrationError, "não é possível vincular recursos órfãos sem um restaurante"
    end

    if fallback_restaurant_id
      fallback_restaurant_id = Integer(fallback_restaurant_id)
      execute "UPDATE categories SET restaurant_id = #{fallback_restaurant_id} WHERE restaurant_id IS NULL"
      execute <<~SQL
        UPDATE products
        SET restaurant_id = COALESCE(categories.restaurant_id, #{fallback_restaurant_id})
        FROM categories
        WHERE products.category_id = categories.id AND products.restaurant_id IS NULL
      SQL
      execute "UPDATE products SET restaurant_id = #{fallback_restaurant_id} WHERE restaurant_id IS NULL"
      execute "UPDATE orders SET restaurant_id = #{fallback_restaurant_id} WHERE restaurant_id IS NULL"
    end

    mismatches = select_all(<<~SQL)
      SELECT products.id AS product_id,
             products.restaurant_id AS target_restaurant_id,
             categories.id AS category_id,
             categories.name AS category_name
      FROM products
      INNER JOIN categories ON categories.id = products.category_id
      WHERE products.restaurant_id <> categories.restaurant_id
    SQL

    mismatches.each do |row|
      target_restaurant_id = Integer(row.fetch("target_restaurant_id"))
      category_name = connection.quote(row.fetch("category_name"))
      target_category_id = select_value(<<~SQL)
        SELECT id
        FROM categories
        WHERE restaurant_id = #{target_restaurant_id}
          AND lower(name) = lower(#{category_name})
        LIMIT 1
      SQL

      target_category_id ||= select_value(<<~SQL)
        INSERT INTO categories (name, description, position, restaurant_id, created_at, updated_at)
        SELECT name, description, position, #{target_restaurant_id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM categories
        WHERE id = #{Integer(row.fetch("category_id"))}
        RETURNING id
      SQL

      execute "UPDATE products SET category_id = #{Integer(target_category_id)} WHERE id = #{Integer(row.fetch("product_id"))}"
    end

    execute <<~SQL
      CREATE UNIQUE INDEX index_categories_on_restaurant_and_lower_name
      ON categories (restaurant_id, lower(name))
    SQL

    change_column_null :categories, :restaurant_id, false
    change_column_null :products, :restaurant_id, false
    change_column_null :orders, :restaurant_id, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "o saneamento de escopo por restaurante não pode ser revertido com segurança"
  end
end
