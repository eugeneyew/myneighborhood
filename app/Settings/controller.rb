require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'

class SettingsController < Rho::RhoController
  include BrowserHelper
  
  def index
  	navbar :title => "Settings"
    @msg = @params['msg']
    render
  end

	# Get AppName and Version from rhoconfig.txt
  def about
  	navbar :title => "About My Neighbourhood", :left => { :action => url_for(:action => :index), :label => "Back" }
    @appname = Rho::RhoConfig.appname
    @appversion = Rho::RhoConfig.version
    render
  end

  def reset
  	navbar :title => "Clear Search History", :left => { :action => url_for(:action => :index), :label => "Back" }, :right => { :action => url_for(:action => :do_reset), :label => "Confirm" }
    render 
  end
  
  def do_reset
    Rhom::Rhom.database_full_reset
    SyncEngine.dosync
    @msg = "Search history has been cleared"
    redirect :action => :index, :query => {:msg => @msg}
  end

  private

	def navbar hash
		# Use Native NavBar on Apple iPhone. use HTML/CSS navbar's on everything else.
		platform = System::get_property('platform')
		if platform == "APPLE"
			@use_html_nav = false
			@title = "My Neighbourhood"
			NavBar.create hash
		else
			@use_html_nav = true
			@title = hash[:title]
			@nav_left = hash[:left] if hash[:left]
			@nav_right = hash[:right] if hash[:right]
		end
	end
  
end
