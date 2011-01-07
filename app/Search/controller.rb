require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'
require 'json'

class SearchController < Rho::RhoController
  include BrowserHelper
  
  def recent
		NavBar.create :title => "Recent"
		@past_searches = Search.find(:all, :order => :last_use_time, :orderdir => "DESC", :per_page => 15)
  	render # => recent.erb
	end

  def wait
  	resolve_type
  	@message = @params["message"] || "Please wait..."
  	render # => wait.erb
	end

  def wait
  	resolve_type
  	@message = @params["message"] || "An error has occured"
  	render # => error.erb
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
  
  # Dispatch a user to the correct action
  def index
  	resolve_type
		if @search_type == :nearby and !GeoLocation.known_position? and (@params["lat"].nil? and @params["long"].nil?)
			NavBar.create :title => "Nearby"
			GeoLocation.set_notification( url_for(:action => :nearby_geo_callback1), default_query_hash_str)
			redirect_for_type :action => :wait, :query => { :message => "Fixing your location..." }
		elsif @search_type == :nearby and GeoLocation.known_position?
			lat = GeoLocation.latitude
			long = GeoLocation.longitude
			redirect_for_type(:action => :geocode_other_location, :query => {:lat => lat, :long => long})
		elsif @search_type == :location and @params["lat"] and @params["long"] and @params["other_location"]
			redirect_for_type(:action => :listing, :query => @params)
		elsif @search_type == :location
			redirect_for_type(:action => :input_other_location) 
		elsif @search_type == :recent and @params["search_id"]
			redirect_for_type(:action => :listing, :query => { :search_id => @params["search_id"] })
		elsif @search_type == :recent 
			redirect_for_type(:action => :recent)
		else
			redirect_for_type(:action => :error) 
		end
		@message = "Processing..."
		render :wait # Show the waitpage, when complete we will be redirected to listing
  end

  def listing
  	resolve_type

  	# Send them back to the index if we have no location.
  	return redirect_for_type(:action => :error) unless @params["lat"] and @params["long"] if @search_type != :recent

		# We should have a text address for this location, either what they entered or what we reverse geocoded
  	return redirect_for_type(:action => :error) if @search_type != :recent and !@params["other_location"]

  	# Send them back to the index is search type is recent yet we have no search id (or it does not exist)
		return redirect_for_type(:action => :error) if @search_type == :recent and !@params["search_id"]

		if @search_type != :recent
			@lat = @params["lat"]
			@long = @params["long"]
			@location = @params["other_location"]
		else
			@search = Search.find(@params["search_id"])
			@lat = @search.lat
			@long = @search.long
			@location = @search.location
		end
  
  	# Setup NavBar as required.
  	if @search_type == :nearby
			NavBar.create :title => @location
		else 
			url = url_for_type(:action => :input_other_location)
			url = url_for_type(:action => :recent) if @search_type == :recent
			NavBar.create :title => @location, :left => {:action => url, :label => "Back"}
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

		if @params["other_location"] # Geocode an address
			key = "address"
			val = @params["other_location"]
			params = {}
			cb_action = :geocode_other_location_callback
		elsif @params["lat"] and @params["long"] # Reverse geocode a lat/long
			key = "latlng"
			val = sprintf("%s,%s", @params["lat"], @params["long"])
			params = { :lat => @params["lat"], :long => @params["long"] }
			cb_action = :reverse_geocode_callback
		end

		url = sprintf(Rho::RhoConfig.google_geocoding_url, key, Rho::RhoSupport.url_encode(val))
		Rho::AsyncHttp.get(
				:url => url,
				:callback => (url_for_type :action => cb_action),
				:callback_param => query_hash_to_str(default_query_hash.merge(params)))

		@message = "Searching for location..."
		render :action => :wait
	end

	def reverse_geocode_callback
   if @params['status'] != 'ok'
      puts " Rho error : #{Rho::RhoError.new(@params['error_code'].to_i).message}"
      puts " Http error : #{@params['http_error']}"
      puts " Http response: #{@params['body']}"
      WebView.navigate ( url_for_type :action => :error ) 
    else
    	obj = @params["body"]
    	if obj["status"] != "OK" or obj["results"].length == 0
    		# No Results Found. Use "Lat,Long",  as locatoin name and send them on their way.
    		#WebView.navigate url_for_type(:action => :input_other_location, :query => { :error => "Address not found" })
    		location = sprintf("%s,%s", @params["lat"], @params["long"])
			else
				location = obj["results"][0]["formatted_address"]
			end
			WebView.navigate url_for_type(:action => :listing, :query => {:lat => @params["lat"], :long => @params["long"], :other_location => location})
		end
	end

	def geocode_other_location_callback
   if @params['status'] != 'ok'
      puts " Rho error : #{Rho::RhoError.new(@params['error_code'].to_i).message}"
      puts " Http error : #{@params['http_error']}"
      puts " Http response: #{@params['body']}"
      WebView.navigate ( url_for_type :action => :geolocation_error ) 
    else
    	obj = @params["body"]
    	if obj["status"] != "OK" or obj["results"].length == 0
    		# No Results Found
    		WebView.navigate url_for_type(:action => :input_other_location, :query => { :error => "Address not found" })
    	elsif obj["results"].length > 1
    		# More than one result found.
    		str = obj["results"].inject("[") { |a, pm| a += '"' + pm["formatted_address"] + '",' } + "]" # No JSON.generate in this version... :(
    		WebView.navigate url_for_type(:action => :select_geocode_results, :query => { :addresses => Rho::RhoSupport.url_encode(str) })
			else
				coords = obj["results"][0]["geometry"]["location"]
				location = obj["results"][0]["formatted_address"]
				WebView.navigate url_for_type(:action => :listing, :query => {:lat => coords["lat"], :long => coords["lng"], :other_location => location})
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
			GeoLocation.set_notification( url_for_type(:action => :nearby_geo_callback2), default_query_hash_str) 
			redirect_for_type :action => :wait, :query => { :message => "Fixing your location..." }
		end
	end
	
	def nearby_geo_callback2
		webview_navigate_for_type(:index) if @params["known_position"].to_i != 0 && @params["status"] == "ok"
		webview_navigate_for_type(:geolocation_error) if @params["known_position"].to_i == 0 || @params["status"] != "ok"
	end

	def map

  	resolve_type

  	# Send them back to the index if we have no location.
  	return redirect_for_type(:action => :index) if !(@params["lat"] and @params["long"]) and @search_type != :recent

  	# Send them back to the index if the search type is not nearby and we dont have a loction input
  	return redirect_for_type(:action => :index) if @search_type == :location and !@params["other_location"]

  	# Send them back to the index is search type is recent yet we have no search id (or it does not exist)
		return redirect_for_type(:action => :index) if @search_type == :recent and !@params["search_id"]

		if @search_type != :recent
			@lat = @params["lat"]
			@long = @params["long"]
			@location = @params["other_location"]
			params = @params
		else
			@search = Search.find(@params["search_id"])
			@lat = @search.lat
			@long = @search.long
			@location = @search.location
			params = { :lat => @lat, :long => @long, :location => @location, :search_id => @search.object } 
		end
		
		# Call GAE Data Service then display the map
		# or used saved search data...
		url = sprintf("%s/parking_facility/%s,%s", Rho::RhoConfig.data_url_base, Rho::RhoSupport.url_encode(@lat), Rho::RhoSupport.url_encode(@long))
		puts " Calling URL: " + url
		Rho::AsyncHttp.get(
				:url => url,
				:callback => (url_for_type :action => :display_mapped_data_callback),
				:callback_param => query_hash_to_str(default_query_hash.merge(params)))
		
		@message = "Retrieving data..."
		render :action => :wait

	end

  def display_mapped_data_callback

  	resolve_type

   if @params['status'] != 'ok'
  		# The HTTP request for data failed with an error. Display an error.
      puts " Rho error : #{Rho::RhoError.new(@params['error_code'].to_i).message}"
      puts " Http error : #{@params['http_error']}"
      puts " Http response: #{@params['body']}"
			return WebView.navigate url_for_type(:action => :error, :query => {})
		end

		@lat = @params["lat"]
		@long = @params["long"]
		@location = @params["other_location"]

		# Add this search to search history. We will use it to populate the Recent tab.
		if @params["search_id"]
			@search = Search.find(@params["search_id"])
			@search.last_use_time = Time.now
			@search.save
		else
			Search.create({
				:type => @search_type,
				:location => @location,
				:category => "Parking",
				:lat => @lat,
				:long => @long,
				:last_use_time => Time.now
			})
		end
    	
    # Response is automagically parsed into a ruby Hash object
    #obj = Rho::JSON.parse(@params["body"])
    obj = @params["body"]

    annotations = obj["parkingFacilityList"].map do |pf|
			{ :latitude => pf["latitude"],
				:longitude => pf["longitude"],
				:title => pf["entityName"],
				:subtitle => sprintf("%s %s %s", pf["addressBuilding"], pf["addressStreetName"], pf["addressCity"]),
				:url => "" }
		end

		map_params = {
			:settings => {
			  :map_type => "roadmap",
				:region => [@lat, @long, 0.01, 0.01],
				:zoom_enabled => true
			},
			:annotations => annotations
		}

		# Show the map
		MapView.create map_params

		# Put the listings page behind the plotted map
		WebView.navigate url_for_type(:action => :listing, :query => {:lat => @lat, :long => @long, :other_location => @location })

	end

  private
   
		def resolve_type
			return @search_type = @params["type"].to_sym if @params["type"]
			@search_type = :unknown
		end

		def default_query_hash
			base = { :type => @params["type"] }
			base[:search_id] = @search.object unless @search.nil?
			base
		end

		def default_query_hash_str
			query_hash_to_str(default_query_hash)
		end

		def query_hash_to_str(hash)
			hash.inject("") { |a,b| a += sprintf("&%s=%s", b[0], b[1]) }[1..-1]
		end

		def url_for_type(hash)
			hash[:query] = hash[:query].merge(default_query_hash) rescue default_query_hash
			url_for(hash)
		end
		
		def redirect_for_type(hash)
			redirect url_for_type(hash)
		end

		def webview_navigate_for_type(action)
			WebView.navigate url_for(:action => action, :query => default_query_hash)
		end

end

