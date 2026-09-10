class CreateMenuOcrImportSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_ocr_import_sessions do |t|
      t.references :restaurant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "uploaded"
      t.string :stage, null: false, default: "upload"
      t.string :source_path, null: false
      t.string :source_filename, null: false
      t.string :source_content_type, null: false
      t.jsonb :draft, null: false, default: {}
      t.jsonb :warnings, null: false, default: []
      t.string :failure_code
      t.datetime :expires_at, null: false
      t.datetime :confirmed_at
      t.timestamps
    end
    add_index :menu_ocr_import_sessions, %i[restaurant_id user_id created_at], name: "index_ocr_sessions_rate_limit"
    add_index :menu_ocr_import_sessions, :expires_at
  end
end
