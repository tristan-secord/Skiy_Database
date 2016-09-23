# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
include ActionController::HttpAuthentication::Token::ControllerMethods

module ApplicationCable
  class Connection < ActionCable::Connection::Base
  	identified_by :current_user

	def connect
    	self.current_user = find_verified_user
    	reject_unauthorized_connection if self.current_user.nil?
	end

	def find_verified_user
    	authenticate_or_request_with_http_token do |token, options|
      		@user = User.where('users.api_authtoken = ? AND users.authtoken_expiry > ?', token, Time.now).first
      	end
    end
  end
end