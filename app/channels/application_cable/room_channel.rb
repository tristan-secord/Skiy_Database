# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class RoomChannel < ApplicationCable::Channel
  def subscribed
  	@session = ActiveSession.where(:id => params[:id]).first
  	if @session
  		@senderID = @session[:friend_id]
  		@channel = 'room_channel_' + @senderID.to_s
  		stream_from @channel
  	end
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    @session = ActiveSession.where(:id => params[:id]).first
    if @session
      if @session[:request_type] = 'SEND'
        if @session != nil
          #unsubscribe sent from sender
          @SenderSessions = ActiveSession.where('friend_id = ? AND request_type != ? AND status IS NOT NULL AND expiry_date > ?', @session[:friend_id], 'SEND', Time.now)
          @SenderSessions.each do |session| 
            #CLEAR DATA IN SERVER
            session.status = nil
            session.save
            #SEND UNSUBSCRIBE REQUESTER TO EACH USER
            @payload = current_user.first_name + ' has stopped transmitting their location. You are no longer tracking this user.'
            @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', session[:user_id], false, Time.now)
            User.notify_ios(session[:user_id], 'UNSUBSCRIBE_REQUESTER', @payload, @notifications.count, true, {"session_id": session[:id]}.as_json)
          end
        end
      elsif @session[:request_type] = 'REQUEST'
        #unsubscribe sent from receiver
        if @session.status != nil
          @session.status = nil
          @session.save
          @SenderSessions = ActiveSession.where('user_id = ? AND status IS NOT NULL AND expiry_date > ? AND request_type = ?', @session[:friend_id], Time.now, 'SEND')
          if @SenderSessions.count <= 0 
            #push notification to sender to unsubscribe
            @payload = 'There are currently no users tracking your location.'
            @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', @session[:friend_id], false, Time.now)
            User.notify_ios(@session[:friend_id], 'UNSUBSCRIBE_SENDER', @payload, @notifications.count, true, {"session_id": @session[:id]}.as_json)
          end
        end
      end
    else
      puts 'Cannot find session'
      e = Error.new(:status => 500, :message => "Could not find this session. Please try again")
      render :json => e.to_json, :status => 500
    end
  end

  def locUpdate(data) 
  	#ADD TO SERVER (LOCATIONS)
  	@channel = 'room_channel_' + current_user[:id].to_s
    data["first_name"] = current_user[:first_name].to_s
    data["last_name"] = current_user[:last_name].to_s
  	ActionCable.server.broadcast(@channel, data)
  end
end
