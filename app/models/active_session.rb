class ActiveSession < ActiveRecord::Base
	belongs_to :user

	validates_presence_of :user_id
	validates_presence_of :friend_id
	validates_presence_of :channel_name
	validates_presence_of :request_type
end