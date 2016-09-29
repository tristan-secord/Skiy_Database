class ApiController < ApplicationController
	http_basic_authenticate_with name:ENV["API_AUTH_NAME"], password:ENV["API_AUTH_PASSWORD"], :only => [:signup, :signin, :get_token]  
	before_filter :check_for_valid_authtoken, :except => [:signup, :signin, :get_token]

	def signup
		if request.post?
			if params && params[:first_name] && params[:last_name] && params[:email] && params[:username] && params[:password]

				params[:user] = Hash.new
				params[:user][:first_name] = params[:first_name]
				params[:user][:last_name] = params[:last_name]
				params[:user][:email] = params[:email]
				params[:user][:username] = params[:username]

				begin
					decrypted_pass = AESCrypt.decrypt(params[:password], ENV["API_AUTH_PASSWORD"])
				rescue Exception => e
					decrypted_pass = nil
				end

				params[:user][:password] = decrypted_pass
				params[:user][:verification_code] = rand_string(20)

				user = User.new(user_params)

				if user.save
					render :json => user.to_json, :status => 200
				else 
					error_str = ""

					user.errors.each{|attr, msg|
						error_str += "#{attr} - #{msg}\n"
					}

					e = Error.new(:status => 400, :message => error_str)
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 400, :message => "Looks like your missing some vital information!")
				render :json => e.to_json, :status => 400
			end
		end
	end	

	def signin
		if request.post?
			if params && params[:email] && params[:password] && params[:device_id]
				user = User.where(:email => params[:email]).first
				if !user
					user = User.where(:username => params[:email]).first
				end

				if user
					if User.authenticate(params[:email], params[:password])
						device = Device.where(:user_id => user.id).first
						if !user.api_authtoken || (user.api_authtoken && user.authtoken_expiry < Time.now) || !device || (device && device.registration_id != params[:device_id])
							auth_token = rand_string(20)
							auth_expiry = Time.now + (24*60*60*60)
							while User.where(:api_authtoken => auth_token).first != nil
								auth_token = rand_string(20)
								auth_expiry = Time.now + (24*60*60*30)
							end
							user.update_attributes(:api_authtoken => auth_token, :authtoken_expiry => auth_expiry)
						end
						if device
							if device[:registration_id] != params[:device_id]
								#send push notification to old device
								User.notify_ios(user.id, "SIGNOUT", "You have been signed out. Account has been accessed on another device. If this was not you please change your password!", 0, nil)
								device.registration_id = params[:device_id]
								device.authtoken_expiry = user.authtoken_expiry
							end
						else
							device = Device.new(:user_id => user.id, :registration_id => params[:device_id], :device_type => 'ios', :authtoken_expiry => user.authtoken_expiry)
						end
						device.save
						@result = {}
						#get top 20 notifications
						@notifications = PendingNotification.where('user_id = ? AND category != ?', user.id, 'FRIEND_REQUEST').order('created_at desc').first(20)
						@result["user"] = user.as_json(:only => [:first_name, :last_name, :email, :username, :api_authtoken, :authtoken_expiry])
						@result["notifications"] = @notifications.as_json
						render :json => @result.as_json, :status => 200
					else
						e = Error.new(:status => 401, :message => "I think you may have entered the wrong password...")
						render :json => e.to_json, :status => 401
					end
				else
					e = Error.new(:status => 400, :message => "Huh... Looks like we can't find any user by that email.")
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 400, :message => "Looks like your missing some vital information!")
				render :json => e.to_json, :status => 400
			end 
		end
	end

#  NEEDS WORK !!!#
	def signout
		if request.get?
			if @user
				device = Device.where(:user_id => @user.id).first
				if device
					device.destroy
				end
				render :nothing => true, :status => 200
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
				render :json => e.to_json, :status => 401
			end
		end
	end


	def findFriend
		if request.post?
			@users = User.where(first_name: params[:search_text])
			render :json => @users.to_json(:only => [:id, :first_name, :last_name, :username]), :status => 200
    	end
    end

    def getFriends
    	if request.get?
    		if @user
					@pending = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'pending').as_json(:only => [:id, :first_name, :last_name, :username, :email])
					@requested = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'requested').as_json(:only => [:id, :first_name, :last_name, :username, :email])
					@friends = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'friends').as_json(:only => [:id, :first_name, :last_name, :username, :email])

					@result = {}
					@result["pending"] = @pending
					@result["requested"] = @requested
					@result["friends"] = @friends
					render :json => @result.as_json, :status => 200
			else
				e = Error.new(:status => 400, :message => "Could not find you")
    			render :json => e.to_json, :status => 400
    		end
    	end
    end

    def checkOldData
    	if request.post?
    		if @user
	    		if params && params[:data_refresh]
	    			@pending = []
	    			@requested = []
	    			@friends = []
					@relationships = Friend.where(:user_id => @user.id)
					@relationships.each do |relationship|
						if !params[:data_refresh].any? {|data| data[:id].to_i == relationship.friend_id && data[:updated_at].to_time >= relationship.updated_at}
							# ADD PERSON
							case relationship.friend_status
							when 'pending'
								@pending.push(User.where(:id => relationship.friend_id).first.as_json(:only => [:id, :first_name, :last_name, :username, :email]))
							when 'requested'
								@requested.push(User.where(:id => relationship.friend_id).first.as_json(:only => [:id, :first_name, :last_name, :username, :email]))
							when 'friends'
								@friends.push(User.where(:id => relationship.friend_id).first.as_json(:only => [:id, :first_name, :last_name, :username, :email]))
							end
						end
					end
					@result = {}
					@result["pending"] = @pending
					@result["requested"] = @requested
					@result["friends"] = @friends
					render :json => @result.as_json, :status => 200
		    	else
					@pending = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'pending').as_json(:only => [:id, :first_name, :last_name, :username, :email])
					@requested = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'requested').as_json(:only => [:id, :first_name, :last_name, :username, :email])
					@friends = User.joins('JOIN friends ON friends.friend_id = users.id').where('friends.user_id = ? AND friends.friend_status = ?', @user.id, 'friends').as_json(:only => [:id, :first_name, :last_name, :username, :email])

					@result = {}
					@result["pending"] = @pending
					@result["requested"] = @requested
					@result["friends"] = @friends
					render :json => @result.as_json, :status => 200
				end
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
    			render :json => e.to_json, :status => 401
    		end
    	end
    end

	def addFriend
		if request.post?
			if @user
				if params && params[:username] 
					@friend = User.where(:username => params[:username]).first
					if @friend
						@forward_relationship = Friend.where(:user_id => @user[:id], :friend_id => @friend[:id]).first
						if @forward_relationship
							@backward_relationship = Friend.where(:friend_id => @user[:id], :user_id => @friend[:id]).first
							case @forward_relationship[:friend_status]
							when 'pending'
								#change forward relationship to friend
								@forward_relationship[:friend_status] = 'friends'
								@forward_relationship.save
								#change backward relationship to friend
								@backward_relationship[:friend_status] = 'friends'
								@backward_relationship.save
								render :nothing => true, :status => 200
							when 'requested'
								#wrong direction - return error and new friend info
								e = Error.new(:status => 400, :message => "Already requested to be friends. Please wait for this person to accept your request.")
	    						render :json => e.to_json, :status => 400
							when 'friends'
								#already friends - return error and new friend info
								e = Error.new(:status => 400, :message => "You are already friends with this user.")
	    						render :json => e.to_json, :status => 400
							end
						else
							# make a forward_relationship requested
							@forward_relationship = Friend.new(:user_id => @user.id, :friend_id => @friend[:id], :friend_status => 'requested')
							@forward_relationship.save
							# make a reverse_relationship pending
							@reverse_relationship = Friend.new(:user_id => @friend[:id], :friend_id => @user[:id], :friend_status => 'pending')
							@reverse_relationship.save
							# send push notification to friend
							@friend_device = Device.where(:user_id => @friend[:id]).first
							@payload = @user.first_name + " " + @user.last_name + " has requested to be your friend."
							#save to pending notifications
							@notification = PendingNotification.new(:user_id => @friend[:id], :sender_id => @user.id, :category => "FRIEND_REQUEST", :payload => @payload, :read => "f")
							@notification.save
							#get pending notifications count
							@friend_notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', @friend[:id], false, Time.now)
							if @friend_device && @friend_device.authtoken_expiry > Time.now && @friend_device.registration_id
								User.notify_ios(@friend[:id], "FRIEND_REQUEST", @payload, @friend_notifications.count, @user.as_json(:only => [:id, :first_name, :last_name, :username, :email]))
							end
							render :nothing => true, :status => 200
						end
					else 
						# couldnt find friend
						e = Error.new(:status => 400, :message => "Could not find this user. Please try again")
    					render :json => e.to_json, :status => 400
					end
				else 
					e = Error.new(:status => 400, :message => "Missing parameters. Please try again")
					render :json => e.to_json, :status => 400
				end
			else 
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
    			render :json => e.to_json, :status => 401
			end
		end
	end

	def removeFriend
		if request.post?
			if @user
				if params && params[:username]
					@friend = @friend = User.where(:username => params[:username]).first
					if @friend
						@forward_relationship = Friend.where(:user_id => @user[:id], :friend_id => @friend[:id]).first
						if @forward_relationship
							Friend.find(@forward_relationship[:id]).destroy
						end
						@reverse_relationship = Friend.where(:user_id => @friend[:id], :friend_id => @user[:id]).first
						if @reverse_relationship
							Friend.find(@reverse_relationship[:id]).destroy
						end
						render :nothing => true, :status => 200
					else 
						e = Error.new(:status => 400, :message => "Could not find this user. Please try again")
						render :json => e.to_json, :status => 400
					end
				else
					e = Error.new(:status => 400, :message => "Missing parameters. Please try again")
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
				render :json => e.to_json, :status => 401
			end
		end
	end

	def getNotifications
		if request.post?
			if @user
				if params && params[:badge_count]
					@notifications = PendingNotification.where('user_id = ?', @user.id).order('created_at DESC').first(params[:badge_count])
					@notifications.each do |notification|
						notification.read = 't'
						notification.save
					end
					@locNotifications = @notifications.select do |notification|
						notification.category != 'FRIEND_REQUEST'
					end
					@result = {}
					#Add except or only to as json?????
					@result["notifications"] = @locNotifications.as_json
					render :json => @result.as_json, :status => 200
				else 
					e = Error.new(:status => 400, :message => "Missing parameters. Please try again")
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
				render :json => e.to_json, :status => 401
			end
		end
	end

	def locRequest
		if request.post?
			if @user
				if params && params[:request_type] && params[:id]
					case params[:request_type]
					when 'REQUEST'
						#check if a session between these two users already exists
						@old_session = ActiveSession.where('user_id = ? AND friend_id = ? AND expiry_date > ? AND request_type != ? AND status IS NOT NULL', @user.id, params[:id], Time.now, 'SEND').first
						if @old_session
							e = Error.new(:status => 409, :message => "Already requested this users location. Waiting for the user to respond.")
							render :json => e.to_json, :status => 409
						else 
							#create session
							@expiry = Time.now + (3*60*60)
							@channel = 'room_channel_' + params[:id].to_s
							@session = ActiveSession.new(:user_id => @user.id, :friend_id => params[:id], :request_type => params[:request_type], :expiry_date => @expiry, :status => "pending", :channel_name => @channel)
							@session.save
							#send push notification
							@payload = @user.first_name + " " + @user.last_name + " has requested your location."
							@notification = PendingNotification.new(:user_id => params[:id], :sender_id => @user.id, :category => "REQUEST_LOCATION", :payload => @payload, :read => "f")
							@notification.save
							#get pending notifications count
							@friend_notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', params[:id], false, Time.now)
							@friend_device = Device.where(:user_id => params[:id]).first
							if @friend_device && @friend_device.authtoken_expiry > Time.now && @friend_device.registration_id
								User.notify_ios(params[:id], "REQUEST_LOCATION", @payload, @friend_notifications.count, @session.as_json)
							end
							render :json => @session.as_json, :status => 200
						end
					when 'SHARE'
					when 'SEND'
					end
				else  
					e = Error.new(:status => 400, :message => "Missing parameters. Please try again")
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
				render :json => e.to_json, :status => 401
			end
		end
	end

	def acceptRequest
		if request.post?
			if @user
				if params && params[:id]
					@session = ActiveSession.where(:id => params[:id]).first
					if @session && @session.status != nil
						@session.status = "Active"
						@session.save
						@toUser = User.where(:id => @session[:user_id]).first
						@payload = @user[:first_name].to_s + ' ' + @user[:last_name].to_s + ' has accepted your request. You are now tracking their location.'
						@friend_notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', @session[:friend_id], false, Time.now)
						User.notify_ios(@session[:user_id], "ACCEPTED", @payload, @friend_notifications.count, @session.as_json)
						render :nothing => true, :status => 200
					else
						e = Error.new(:status => 500, :message => "Could not find this session. Please try again")
						render :json => e.to_json, :status => 500
					end
				else  
					e = Error.new(:status => 400, :message => "Missing parameters. Please try again")
					render :json => e.to_json, :status => 400
				end
			else
				e = Error.new(:status => 401, :message => "Unauthorized Access. Please try again")
				render :json => e.to_json, :status => 401
			end
		end
	end


	def rand_string(len)
    	o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    	string  =  (0..len).map{ o[rand(o.length)]  }.join

    	return string
  	end

	def user_params
	    params.require(:user).permit(:first_name, :last_name, :email, :username, :password, :password_hash, :password_salt, :verification_code, 
	    :email_verification, :api_authtoken, :authtoken_expiry)
	 end

	 def check_for_valid_authtoken
    	authenticate_or_request_with_http_token do |token, options|     
      	@user = User.where('users.api_authtoken = ? AND users.authtoken_expiry > ?', token, Time.now).first
    end
  end
end
