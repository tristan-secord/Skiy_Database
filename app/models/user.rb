require 'houston'

class User < ActiveRecord::Base
	ActiveRecord::Base.include_root_in_json = false
	attr_accessor :password
	before_save :encrypt_password

	validates_confirmation_of :password
	validates_presence_of :email, :on => :create
	validates_presence_of :username, :on => :create
	validates :password, length: { in: 6..30 }, :on => :create


	validates_format_of :email, :with => /\A[^@]+@([^@\.]+\.)+[^@\.]+\z/
	validates_uniqueness_of :email
	validates_uniqueness_of :username
	has_many :friends
	has_many :devices

	def encrypt_password
		if password.present?
			self.password_salt = BCrypt::Engine.generate_salt
			self.password_hash = BCrypt::Engine.hash_secret(password, password_salt)
		end 
	end 

	def self.authenticate(login_name, password)
		user = self.where("email =?", login_name).first

		if !user
			user = self.where("username =?", login_name).first
		end

		if user
			begin
				password = AESCrypt.decrypt(password, ENV["API_AUTH_PASSWORD"])
			rescue Exception => e
				password = nil
				puts "error - #{e.message}"
			end

			if user.password_hash == BCrypt::Engine.hash_secret(password, user.password_salt)
				user
			else
				nil
			end
		else
			nil
		end
	end

	def self.notify_ios(id, text, data = nil)
	    #apn = Houston::Client.development
	    #apn.certificate = File.read(ENV['APPLE_DEV_CERTIFICATE']) # certificate from prerequisites
	    #device = Device.where(:user_id => id)
	    #notification = Houston::Notification.new(device: device.registration_id)
		#notification.alert = text
		# take a look at the docs about these params
		#notification.badge = 57
		#notification.sound = "sosumi.aiff"
		#notification.custom_data = data unless data.nil?
		#apn.push(notification)
	end

	def to_json(options={})
		options[:except] ||= [:id, :password_hash, :password_salt, :email_verification, :verification_code, :created_at, :updated_at]
		super(options)
	end

	def self.search(search)
		where("first_name LIKE ?", "%#{search}%").to_json
  	end
end
