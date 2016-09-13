class CreatePendingNotifications < ActiveRecord::Migration
  def change
    create_table :pending_notifications do |t|
      t.integer :user_id
      t.integer :sender_id
      t.string :category
      t.string :payload
      t.datetime :expiry

      t.timestamps null: false
    end
  end
end
