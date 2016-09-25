# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class RoomChannel < ApplicationCable::Channel
  def subscribed
  	if params
  		puts params
  	else
  		puts 'NO params'
  	end

  	stream_from 'RoomChannel5'
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def locUpdate(data) 
  	#ADD TO SERVER (LOCATIONS)
  	ActionCable.server.broadcast("RoomChannel#{current_user.id}", data)
  end
end
