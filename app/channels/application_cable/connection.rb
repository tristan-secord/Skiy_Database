# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  	identified_by :current_user

	def connect
    	self.current_user = find_verified_user
    	reject_unauthorized_connection if self.current_user.nil?
	end

	def find_verified_user
    	if current_user = User.where('users.api_authtoken = ? AND users.authtoken_expiry > ?', request.headers['Authorization'], Time.now).first
    		current_user
    	else
    		reject_unauthorized_connection
    	end
    end
  end
end