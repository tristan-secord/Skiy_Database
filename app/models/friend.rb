class Friend < ActiveRecord::Base
	belongs_to :users

	validates_presence_of :user_id
	validates_presence_of :friend_id

	def getStatus(options={})
		options[:except] ||= [:user_id, :friend_id, :created_at, :updated_at]
		super(options)
	end
end
