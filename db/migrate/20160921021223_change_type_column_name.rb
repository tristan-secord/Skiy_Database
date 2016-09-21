class ChangeTypeColumnName < ActiveRecord::Migration
  def change
  	    rename_column :active_sessions, :type, :request_type
  end
end
