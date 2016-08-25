class CreateDevices < ActiveRecord::Migration
  def change
    create_table :devices do |t|
      t.integer :user_id
      t.string :registration_id
      t.string :device_type

      t.timestamps null: false
    end
  end
end
