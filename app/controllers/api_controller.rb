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
						error_str += "#{attr} - #{msg}"
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
						if !user.api_authtoken || (user.api_authtoken && user.authtoken_expiry < Time.now)
							auth_token = rand_string(20)
							auth_expiry = Time.now + (24*60*60*60)
							while User.where(:api_authtoken => auth_token).first != nil
								auth_token = rand_string(20)
								auth_expiry = Time.now + (24*60*60*30)
							end
							user.update_attributes(:api_authtoken => auth_token, :authtoken_expiry => auth_expiry)
						end
						device = Device.where(:user_id => user.id).first
						if device
							#send push notification to old device
							User.notify_ios(user.id, "SIGNOUT", "You have been signed out. Account has been accessed on another device.", nil)
							device.registration_id = params[:device_id]
							device.authtoken_expiry = user.authtoken_expiry
						else
							device = Device.new(:user_id => user.id, :registration_id => params[:device_id], :device_type => 'ios', :authtoken_expiry => user.authtoken_expiry)
						end
						device.save
						render :json => user.to_json, :status => 200
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
      	@user = User.where(:api_authtoken => token).first      
    end
  end
end
