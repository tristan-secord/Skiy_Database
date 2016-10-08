# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class RoomChannel < ApplicationCable::Channel
  def subscribed
  	@session = ActiveSession.where(:id => params[:id]).first
  	if @session
  		@channel = @session[:channel_name].to_s
  		stream_from @channel
  	end
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    @forward_session = ActiveSession.where(:id => params[:id]).first
    if @forward_session
      if @forward_session[:request_type] == 'SEND'
        @reverse_session = ActiveSession.where('user_id = ? AND friend_id = ? AND expiry_date > ? AND request_type = ?', @forward_session[:friend_id], @forward_session[:user_id], Time.now, 'REQUEST').first
        if @reverse_session
          if @forward_session.status != nil
            @forward_session.status = nil
            @forward_session.save
          end
          #unsubscribe sent from sender
          @ReceivingSessions = ActiveSession.where('user_id = ? AND request_type = ? AND status IS NOT NULL AND expiry_date > ?', @forward_session[:friend_id], 'REQUEST', Time.now)
          @ReceivingSessions.each do |session| 
            #CLEAR DATA IN SERVER
            session.status = nil
            session.save
            #SEND UNSUBSCRIBE REQUESTER TO EACH USER
            @payload = current_user.first_name + ' has stopped transmitting their location. You are no longer tracking this user.'
            @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', session[:user_id], false, Time.now)
            User.notify_ios(session[:user_id], 'UNSUBSCRIBE_REQUESTER', @payload, @notifications.count, true, {"session_id": session[:id]}.as_json)
          end
          @SendingSessions = ActiveSession.where('user_id = ? AND request_type = ? AND status IS NOT NULL AND expiry_date > ?', @forward_session[:user_id], 'SEND', Time.now)
          @SendingSessions.each do |session|
            #CLEAR DATA IN SERVER
            session.status = nil
            session.save
          end
        else
          puts ("There was a problem finding reverse session. Forward session - SEND. Please try again")
        end
      elsif @forward_session[:request_type] == 'REQUEST'
        @reverse_session = ActiveSession.where('user_id = ? AND friend_id = ? AND expiry_date > ? AND request_type = ?', @forward_session[:friend_id], @forward_session[:user_id], Time.now, 'SEND').first
        if @reverse_session
          #unsubscribe sent from receiver
          if @forward_session.status != nil
            @forward_session.status = nil
            @forward_session.save
          end
          if @reverse_session.status != nil 
            @reverse_session.status = nil
            @reverse_session.save
            @SenderSessions = ActiveSession.where('user_id = ? AND status IS NOT NULL AND expiry_date > ? AND request_type = ?', @forward_session[:friend_id], Time.now, 'SEND')
            if @SenderSessions.count <= 0 
              #push notification to sender to unsubscribe
              @payload = 'There are currently no users tracking your location.'
              @notifications = PendingNotification.where('user_id = ? AND read = ? AND (expiry IS NULL OR expiry > ?)', @forward_session[:friend_id], false, Time.now)
              User.notify_ios(@forward_session[:friend_id], 'UNSUBSCRIBE_SENDER', @payload, @notifications.count, true, {"session_id": @reverse_session[:id]}.as_json)
            end
          end
        else 
          puts("There was a problem finding reverse session. Forward session - REQUEST. Please try again")
        end
      end
    else
      puts("There was a problem finding forward session. Please try again")
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
