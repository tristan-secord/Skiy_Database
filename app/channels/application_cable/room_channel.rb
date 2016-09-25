# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class RoomChannel < ApplicationCable::Channel
  def subscribed
  	stream_from 'RoomChannel#{current_user.id}'
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def locUpdate(data) 
  	#ADD TO SERVER (LOCATIONS)
  	ActionCable.server.broadcast("locations", data)
  end
end
