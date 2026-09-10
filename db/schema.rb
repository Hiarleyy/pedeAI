# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_09_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "restaurant_id", null: false
    t.datetime "updated_at", null: false
    t.index "restaurant_id, lower((name)::text)", name: "index_categories_on_restaurant_and_lower_name", unique: true
    t.index ["restaurant_id"], name: "index_categories_on_restaurant_id"
  end

  create_table "order_item_addons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "order_item_id", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["order_item_id"], name: "index_order_item_addons_on_order_item_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.string "variant_name"
    t.decimal "variant_price", precision: 10, scale: 2
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "customer_name", null: false
    t.string "customer_phone", null: false
    t.string "delivery_address"
    t.string "order_type", null: false
    t.string "payment_method", null: false
    t.bigint "restaurant_id", null: false
    t.string "status", default: "pending", null: false
    t.string "table_number"
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_orders_on_restaurant_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "product_addons", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["available"], name: "index_product_addons_on_available"
    t.index ["product_id", "name"], name: "index_product_addons_on_product_id_and_name", unique: true
    t.index ["product_id"], name: "index_product_addons_on_product_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "name"], name: "index_product_variants_on_product_id_and_name", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "restaurant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["available"], name: "index_products_on_available"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["restaurant_id"], name: "index_products_on_restaurant_id"
  end

  create_table "restaurants", force: :cascade do |t|
    t.text "banner_url"
    t.datetime "created_at", null: false
    t.string "font_family", default: "inter", null: false
    t.text "logo_url"
    t.text "menu_description"
    t.jsonb "menu_information", default: {}, null: false
    t.string "name", null: false
    t.string "primary_color", default: "#d34000", null: false
    t.text "product_placeholder_url"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_restaurants_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.jsonb "permissions", default: {}, null: false
    t.bigint "restaurant_id"
    t.string "role", default: "funcionario", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["restaurant_id"], name: "index_users_on_one_super_admin_per_restaurant", unique: true, where: "((role)::text = 'superAdmin'::text)"
    t.index ["restaurant_id"], name: "index_users_on_restaurant_id"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "categories", "restaurants"
  add_foreign_key "order_item_addons", "order_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "restaurants"
  add_foreign_key "product_addons", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "restaurants"
  add_foreign_key "users", "restaurants"
end
