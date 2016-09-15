class AddReadToPendingNotifications < ActiveRecord::Migration
  def change
    add_column :pending_notifications, :read, :binary
  end
end
