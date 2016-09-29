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
      if current_user[:id] == @session.friend_id
        #unsubscribe sent from sender
        @SenderSessions = ActiveSession.where('friend_id = ? AND status IS NOT NULL AND expiry_date > ?', @session[:friend_id], Time.now)
        @SenderSessions.each do |session| 
          #CLEAR DATA IN SERVER
          session.status = nil
          session.save
          #SEND UNSUBSCRIBE REQUESTER TO EACH USER
          @payload = ''
          @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', session[:user_id], false, Time.now)
          User.notify_ios(session[:user_id], 'UNSUBSCRIBE_REQUESTER', @payload, @notifications.count, {"session_id": session[:id]}.as_json)
        end
        render :nothing => true, :status => 200
      elsif current_user[:id] == @session.user_id
        @session.status = nil
        @session.save
        #unsubscribe sent from receiver
        @SenderSessions = ActiveSession.where('friend_id = ? AND status IS NOT NULL AND expiry_date > ?', @session[:friend_id], Time.now)
        if @SenderSessions.count > 0 
          render :nothing => true, :status => 200
        else
          #push notification to sender to unsubscribe
          @payload = 'You are no longer being tracked by anyone'
          @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', @session[:friend_id], false, Time.now)
          User.notify_ios(@session[:friend_id], 'UNSUBSCRIBE_SENDER', @payload, @notifications.count, {"session_id": @session[:id]}.as_json)
          render :nothing => true, :status => 200
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
