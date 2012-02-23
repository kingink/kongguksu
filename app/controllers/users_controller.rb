class UsersController < ApplicationController
	include OauthSystem

	before_filter :oauth_login_required, :except => [ :callback, :signout, :index ]
	before_filter :init_user, :except => [ :callback, :signout, :index ]
	before_filter :access_check, :except => [ :callback, :signout, :index ]

	# GET /users
	# GET /users.xml
	def index
	end

	def new
		# this is a do-nothing action, provided simply to invoke authentication
		# on successful authentication, user will be redirected to 'show'
		# on failure, user will be redirected to 'index'
	end
	
	# GET /users/1
	# GET /users/1.xml
	def show
		respond_to do |format|
			format.html # show.html.erb
			format.xml  { render :xml => @user }
		end
	end

	def partialmentions
		if (request.xhr?)
			@messages = self.mentions()
			render :partial => 'users/status', :collection => @messages, :as => :status, :layout => false
		else
			flash[:error] = 'method only supporting XmlHttpRequest'
			user_path(@user)
		end
	end

protected

	def init_user
		begin
			screen_name = params[:id] unless params[:id].nil?
			screen_name = params[:user_id] unless params[:user_id].nil?
			@user = User.find_by_screen_name(screen_name)
			raise ActiveRecord::RecordNotFound unless @user
		rescue
			flash[:error] = 'Sorry, that is not a valid user.'
			redirect_to root_path
			return false
		end
	end
	
	def access_check
		return if current_user.id == @user.id
		flash[:error] = 'Sorry, permissions prevent you from viewing other user details.'
		redirect_to user_path(current_user) 
		return false		
	end	
end
