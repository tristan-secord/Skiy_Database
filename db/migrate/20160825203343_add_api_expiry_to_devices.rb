class AddApiExpiryToDevices < ActiveRecord::Migration
  def change
    add_column :devices, :authtoken_expiry, :datetime
  end
end
