class ChangeExpiryColumnType < ActiveRecord::Migration
  def up
        change_column :active_sessions, :expiry_date, :datetime
    end

    def down
        change_column :active_sessions, :expiry_date, :date
    end
end
