require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'
require 'json'

class SearchController < Rho::RhoController
  include BrowserHelper

  def wait
  	resolve_type
  	NavBar.remove
  	render # => wait.erb
	end

	def geolocation_error
		resolve_type
		NavBar.remove
		render # => geolocation_error.erb
	end
	
	def select_geocode_results
		@addresses = Rho::JSON.parse(@params["addresses"])
		NavBar.create :title => "Select Other Location", :left => {:action => url_for_type(:action => :input_other_location), :label => "Back"}
		render
	end
  
  # Dispatch a user to the correct location
  def index
  	resolve_type
  	NavBar.remove
		if @search_type == :nearby and !GeoLocation.known_position? and (@params["lat"].nil? and @params["long"].nil?)
			GeoLocation.set_notification( url_for(:action => :nearby_geo_callback1), type_queryhashstr)
			redirect_for_type :action => :wait
			return
		elsif @search_type == :nearby and GeoLocation.known_position?
			lat = GeoLocation.latitude
			long = GeoLocation.longitude
			redirect_for_type(:action => :listing, :query => {:lat => lat, :long => long})
		elsif @search_type != :nearby and @params["lat"] and @params["long"] and @params["other_location"]
			redirect_for_type(:action => :listing, :query => @params)
		else
			redirect_for_type(:action => :input_other_location) 
		end
		render :wait # Show the waitpage, when complete we will be redirected to listing
  end

  def listing
  	resolve_type

  	# Send them back to the index if we have no location.
  	return redirect_for_type(:action => :index) unless @params["lat"] and @params["long"]

  	# Send them back to the index if the search type is not nearby and we dont have a loction input
  	return redirect_for_type(:action => :index) if @search_type != :nearby and !@params["other_location"]
		
		@lat = @params["lat"]
		@long = @params["long"]
		@location = @params["other_location"]
  
  	# Setup NavBar as required.
  	if @search_type == :nearby
			NavBar.create :title => "Nearby"
		else 
			NavBar.create :title => @location, :left => {:action => url_for_type(:action => :index), :label => "Back"}
		end
		
		render # => listing.erb
	end

  def input_other_location
  	resolve_type
		@error = @params["error"] unless @params["error"].nil?
		NavBar.create :title => "Other Location"
  	render # => input_other_location.erb
	end

	def geocode_other_location
		addr = @params["other_location"]
		# todo Error handling...

		url = sprintf("http://maps.google.com/maps/geo?q=%s&output=json&key=123abc", Rho::RhoSupport.url_encode(addr))
		Rho::AsyncHttp.get(
				:url => url,
				:callback => (url_for_type :action => :geocode_other_location_callback),
				:callback_param => type_queryhashstr )

		render :action => :wait
	end

	def geocode_other_location_callback
   if @params['status'] != 'ok'
      puts " Rho error : #{Rho::RhoError.new(@params['error_code'].to_i).message}"
      puts " Http error : #{@params['http_error']}"
      puts " Http response: #{@params['body']}"
      WebView.navigate ( url_for_type :action => :geolocation_error ) 
    else
    	obj = Rho::JSON.parse(@params["body"])
    	if obj["Status"]["code"] != 200 or obj["Placemark"].length == 0
    		# No Results Found
    		WebView.navigate url_for_type(:action => :input_other_location, :query => { :error => "Address not found" })
    	elsif obj["Placemark"].length > 1
    		# More than one result found.
    		str = obj["Placemark"].inject("[") { |a, pm| a += '"' + pm["address"] + '",' } + "]" # No JSON.generate in this version... :(
    		WebView.navigate url_for_type(:action => :select_geocode_results, :query => { :addresses => Rho::RhoSupport.url_encode(str) })
			else
				coords = obj["Placemark"][0]["Point"]["coordinates"]
				location = obj["name"]
				WebView.navigate url_for_type(:action => :listing, :query => {:lat => coords[1], :long => coords[0], :other_location => location})
			end
		end
	end

	# We define 2 callbacks for the GeoLocation function.
	# The first one seems to nearly always fail. If it fails,
	# it will invoke a second try and set the callback to callback2. if
	# callback 2 fails it displays an error screen.
	def nearby_geo_callback1
		webview_navigate_for_type(:index) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
  	# Try again if the first call failed, seems to be needed on the simulator...
  	if @params["known_position"].to_i == 0 || @params["status"] != "ok" 
			GeoLocation.set_notification( url_for_type(:action => :nearby_geo_callback2), type_queryhashstr) 
  		redirect_for_type :action => :wait
		end
	end
	
	def nearby_geo_callback2
		webview_navigate_for_type(:index) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
		webview_navigate_for_type(:geolocation_error) if @params["known_position"].to_i == 0 || @params["status"] != "ok"
	end

	def map

  	resolve_type

  	# Send them back to the index if we have no location.
  	return redirect_for_type(:action => :index) unless @params["lat"] and @params["long"]

  	# Send them back to the index if the search type is not nearby and we dont have a loction input
  	return redirect_for_type(:action => :index) if @search_type != :nearby and !@params["other_location"]
		
		@lat = @params["lat"]
		@long = @params["long"]
		@location = @params["other_location"]

		# Call GAE Data Service then display the map
		url = sprintf("http://skawakam6.appspot.com/ws/json/parking_facility/%s/%s", Rho::RhoSupport.url_encode(@lat), Rho::RhoSupport.url_encode(@long))
		Rho::AsyncHttp.get(
				:url => url,
				:callback => (url_for_type :action => :display_mapped_data_callback),
				:callback_param => query_hash_to_str(@params) )
		render :action => :wait

	end

  def display_mapped_data_callback

  	resolve_type

		@lat = @params["lat"]
		@long = @params["long"]
		@location = @params["other_location"]
    	
    # Response is automagically parsed into a ruby Hash object
    #obj = Rho::JSON.parse(@params["body"])
    obj = @params["body"]

    annotations = obj["ParkingFacility"].map do |pf|
			{ :latitude => pf["latitude"],
				:longitude => pf["longitude"],
				:title => pf["entityName"],
				:subtitle => sprintf("%s %s %s", pf["addressBuilding"], pf["addressStreetName"], pf["addressCity"]),
				:url => "" }
		end

		map_params = {
			:settings => {
				:map_type => "standard",
				:region => [@lat, @long, 0.01, 0.01],
				:zoom_enabled => true,
				:scroll_enabled => true,
				:shows_user_location => true,
				:api_key => 'Google Maps API Key'
			},
			:annotations => annotations
		}

		# Show the map
		MapView.create map_params

		# Put the listings page behind the plotted map
		WebView.navigate url_for_type(:action => :listing, :query => {:lat => @lat, :long => @long, :other_location => @location})

	end

  private
   
		def resolve_type
			@search_type = :location
			@search_type = :nearby if @params["type"] == "nearby"
		end

		def type_queryhash
			return { :type => @params["type"] }
		end

		def type_queryhashstr
			query_hash_to_str(type_queryhash)
		end

		def query_hash_to_str(hash)
			hash.inject("") { |a,b| a += sprintf("&%s=%s", b[0], b[1]) }[1..-1]
		end

		def url_for_type(hash)
			hash[:query] = hash[:query].merge(type_queryhash) rescue type_queryhash
			url_for(hash)
		end
		
		def redirect_for_type(hash)
			redirect url_for_type(hash)
		end

		def webview_navigate_for_type(action)
			WebView.navigate url_for(:action => action, :query => type_queryhash)
		end

end

