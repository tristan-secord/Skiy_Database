require 'pusher'

Pusher.app_id = '250199'
Pusher.key = 'c325822a11208350c364'
Pusher.secret = '8b78408edfeeaceff042'
Pusher.logger = Rails.logger
Pusher.encrypted = true

# app/controllers/hello_world_controller.rb
class HelloWorldController < ApplicationController
  def hello_world
    Pusher.trigger('test_channel', 'my_event', {
      message: 'hello world'
    })
  end
end