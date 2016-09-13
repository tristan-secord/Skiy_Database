class PendingNotification < ActiveRecord::Base
	belongs_to :user

	validates_presence_of :user_id
	validates_presence_of :sender_id
	validates_presence_of :category
	validates_presence_of :payload
end
