require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'

class MainController < Rho::RhoController
  include BrowserHelper
  
  def index
    render
  end

  def wait
  	render
	end

  def plotmap
  	if !GeoLocation.known_position?
  		GeoLocation.set_notification( url_for(:action => :geo_callback1), "")
  		redirect :action => :wait
		else
			map_params = {
						:settings => {:map_type => "hybrid",:region => [GeoLocation.latitude, GeoLocation.longitude, 0.2, 0.2],
													:zoom_enabled => true,:scroll_enabled => true,:shows_user_location => false,
													:api_key => 'Google Maps API Key'},
						:annotation => []
			}
			MapView.create map_params
		end
	end

	def geolocation_error
		render
	end

	def geo_callback1
		WebView.navigate url_for(:action => :plotmap) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
  	# Try again if the first call failed, seems to be needed on the simulator..
  	if @params["known_position"].to_i == 0 || @params["status"] != "ok" 
			GeoLocation.set_notification( url_for(:action => :geo_callback2), "") 
  		redirect :action => :wait
		end
	end

	def geo_callback2
		WebView.navigate url_for(:action => :plotmap) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
		WebView.navigate url_for(:action => :geolocation_error) if @params["known_position"].to_i == 0 || @params["status"] != "ok"
	end

end

