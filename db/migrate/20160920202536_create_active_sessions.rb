class CreateActiveSessions < ActiveRecord::Migration
  def change
    create_table :active_sessions do |t|
      t.integer :user_id
      t.integer :friend_id
      t.string :status
      t.string :channel_name
      t.string :type
      t.datetime :expiry_date

      t.timestamps null: false
    end
  end
end
