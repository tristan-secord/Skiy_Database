class Location < ApplicationRecord
	belongs_to :user

	validates_presence_of :user_id
	validates_presence_of :latitude
	validates_presence_of :longitude
end
