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
  end

  def locUpdate(data) 
  	#ADD TO SERVER (LOCATIONS)
  	@channel = 'room_channel_' + current_user[:id].to_s
    data["first_name"] = current_user[:first_name].to_s
    data["last_name"] = current_user[:last_name].to_s
  	ActionCable.server.broadcast(@channel, data)
  end
end
