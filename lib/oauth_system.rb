require 'json'
require 'oauth'

module OauthSystem
	class GeneralError < StandardError
	end
	class RequestError < OauthSystem::GeneralError
	end
	class NotInitializedError < OauthSystem::GeneralError
	end

	# controller method to handle logout
	def signout
		self.current_user = false 
		flash[:notice] = "You have been logged out."
		redirect_to root_url
	end
	
	# controller method to handle twitter callback (expected after login_by_oauth invoked)
	def callback
		self.twitagent.exchange_request_for_access_token( session[:request_token], session[:request_token_secret], params[:oauth_verifier] )
		
		user_info = self.twitagent.verify_credentials
		
		#raise OauthSystem::RequestError unless user_info['id'] && user_info['screen_name'] && user_info['profile_image_url']
		
		# We have an authorized user, save the information to the database.
		@user = User.find_by_screen_name(user_info['screen_name'])
		if @user
			@user.token = self.twitagent.access_token.token
			@user.secret = self.twitagent.access_token.secret
			@user.profile_image_url = user_info['profile_image_url']
		else
			@user= User.new({ 
				:twitter_id => user_info['id'],
				:screen_name => user_info['screen_name'],
				:token => self.twitagent.access_token.token,
				:secret => self.twitagent.access_token.secret,
				:profile_image_url => user_info['profile_image_url'] })
		end
		if @user.save!
			self.current_user = @user
		else
			raise OauthSystem::RequestError
		end
		# Redirect to the show page
		redirect_to user_path(@user)
		
	rescue
		# The user might have rejected this application. Or there was some other error during the request.
		RAILS_DEFAULT_LOGGER.error "Failed to get user info via OAuth"
		flash[:error] = "Twitter API failure (account login)"
		redirect_to root_url
	end

protected
  
    # Inclusion hook to make #current_user, #logged_in? available as ActionView helper methods.
    def self.included(base)
		  base.send :helper_method, :current_user, :logged_in? if base.respond_to? :helper_method
    end

    def twitagent( user_token = nil, user_secret = nil )
		  self.twitagent = TwitterOauth.new( user_token, user_secret )  if user_token && user_secret
		  self.twitagent = TwitterOauth.new( ) unless @twitagent
		  @twitagent ||= raise OauthSystem::NotInitializedError
    end

    def twitagent=(new_agent)
		  @twitagent = new_agent || false
    end
	
    # Accesses the current user from the session.
    # Future calls avoid the database because nil is not equal to false.
    def current_user
		  @current_user ||= (login_from_session) unless @current_user == false
    end
	
    # Sets the current_user, including initializing the OAuth agent
    def current_user=(new_user)
      if new_user
        session[:twitter_id] = new_user.twitter_id
        self.twitagent( user_token = new_user.token, user_secret = new_user.secret )
        @current_user = new_user
      else
        session[:request_token] = session[:request_token_secret] = session[:twitter_id] = nil 
        self.twitagent = false
        @current_user = false
      end
    end

	def oauth_login_required
		logged_in? || login_by_oauth
	end

    # Returns true or false if the user is logged in.
    # Preloads @current_user with the user model if they're logged in.
    def logged_in?
		  !!current_user
    end

    def login_from_session
		  self.current_user = User.find_by_twitter_id(session[:twitter_id]) if session[:twitter_id]
    end

    def login_by_oauth
      request_token = self.twitagent.get_request_token
      session[:request_token] = request_token.token
      session[:request_token_secret] = request_token.secret
      # Send to twitter.com to authorize
      redirect_to request_token.authorize_url
    rescue
      # The user might have rejected this application. Or there was some other error during the request.
      RAILS_DEFAULT_LOGGER.error "Failed to login via OAuth"
      flash[:error] = "Twitter API failure (account login)"
      redirect_to root_url
    end

    # Twitter REST API Method: statuses mentions
    def mentions( since_id = nil, max_id = nil , count = nil, page = nil )
      self.twitagent.mentions( since_id, max_id, count, page )
    rescue => err
      RAILS_DEFAULT_LOGGER.error "Failed to get mentions via OAuth for #{current_user.inspect}"
      flash[:error] = "Twitter API failure (getting mentions)"
      return
    end
end
