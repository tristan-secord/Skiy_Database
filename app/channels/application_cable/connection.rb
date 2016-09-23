# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  	identified_by :current_user

	def connect
    	self.current_user = find_verified_user
    	reject_unauthorized_connection if self.current_user.nil?
	end

	def find_verified_user
    	if current_user = User.find_by(api_authtoken: request.params[:Authorization])
    		current_user
    	elsif current_user = User.find_by(api_authtoken: request.headers['Authorization'])
    		current_user
    	else
    		reject_unauthorized_connection
    	end
    end
  end
end