class CreatePlatformAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_audit_events do |t|
      t.references :platform_user, foreign_key: true
      t.string :actor_identifier
      t.string :action, null: false
      t.string :target_type
      t.bigint :target_id
      t.string :outcome, null: false
      t.text :justification
      t.string :request_id
      t.string :ip_address
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end

    add_index :platform_audit_events, [:target_type, :target_id]
    add_index :platform_audit_events, :action
    add_index :platform_audit_events, :outcome
    add_index :platform_audit_events, :created_at
  end
end
