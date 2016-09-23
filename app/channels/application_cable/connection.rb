# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  	identified_by :current_user

  	include ActionController::HttpAuthentication::Token::ControllerMethods

	def connect
    	self.current_user = find_verified_user
    	reject_unauthorized_connection if self.current_user.nil?
	end

	protected

	def find_verified_user
    	authenticate_or_request_with_http_token do |token, options|
      		User.find_by(auth_token: token)
      	end
    end
  end
end