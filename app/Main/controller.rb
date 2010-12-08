require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'
require 'json'

class MainController < Rho::RhoController
  include BrowserHelper
  
  def index
    render
  end

  def wait
  	render
	end

	def geocode_address
		addr = @params["address"]
		# todo Error handling...

		url = sprintf("http://maps.google.com/maps/geo?q=%s&output=json&key=123abc", Rho::RhoSupport.url_encode(addr))
		Rho::AsyncHttp.get(
				:url => url,
				:callback => (url_for :action => :geocode_address_callback),
				:callback_param => "" )

		render :action => :wait
	end

	def geocode_address_callback
   if @params['status'] != 'ok'
      puts " Rho error : #{Rho::RhoError.new(@params['error_code'].to_i).message}"
      puts " Http error : #{@params['http_error']}"
      puts " Http response: #{@params['body']}"
      WebView.navigate ( url_for :action => :geolocation_error ) 
    else
    	obj = Rho::JSON.parse(@params["body"])
    	if obj["Status"]["code"] != 200 or obj["Placemark"].length == 0
    		# No Results Found
    		WebView.navigate url_for(:action => :specify_location, :query => { :error => "Address not found" })
    	elsif obj["Placemark"].length > 1
    		# More than one result found.
    		str = obj["Placemark"].inject("[") { |a, pm| a += '"' + pm["address"] + '",' } + "]" # No JSON.generate in this version... :(
    		WebView.navigate url_for(:action => :select_geocode_results, :query => { :addresses => Rho::RhoSupport.url_encode(str) })
			else
				coords = obj["Placemark"][0]["Point"]["coordinates"]
				WebView.navigate url_for(:action => :plotmap, :query => {:lat => coords[1], :long => coords[0]})
			end
		end
	end

	def select_geocode_results
		@addresses = Rho::JSON.parse(@params["addresses"])
		render
	end

  def plotmap
		lat = GeoLocation.latitude
		long = GeoLocation.longitude
  	if !GeoLocation.known_position? and (@params["lat"].nil? and @params["long"].nil?)
  		GeoLocation.set_notification( url_for(:action => :geo_callback1), "")
  		redirect :action => :wait
  		return
		elsif @params["lat"] and @params["long"]
				lat = @params["lat"]
				long = @params["long"]
		end

		annotations = []
		map_params = {
			:settings => {
				:map_type => "standard",
				:region => [lat, long, 0.01, 0.01],
				:zoom_enabled => true,
				:scroll_enabled => true,
				:shows_user_location => true,
				:api_key => 'Google Maps API Key'
			},
			:annotation => annotations
		}
		MapView.create map_params

		# Put the index behind the plotted map
		redirect :action => :index

	end

	def specify_location
		@error = @params["error"] unless @params["error"].nil?
		render
	end

	def geolocation_error
		render
	end

	def geo_callback1
		WebView.navigate url_for(:action => :plotmap) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
  	# Try again if the first call failed, seems to be needed on the simulator...
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

