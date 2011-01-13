require 'rho/rhoapplication'

class AppApplication < Rho::RhoApplication
  def initialize
    # Tab items are loaded left->right, @tabs[0] is leftmost tab in the tab-bar
    # Super must be called *after* settings @tabs!
    @tabs = [
      { :label => "Recent", :action => '/app/Search/recent?type=recent', :icon => "/public/images/tabs/11-clock.png", :reload => true },
      { :label => "Nearby",  :action => '/app/Search?type=nearby',  :icon => "/public/images/tabs/74-location.png" }, 
      { :label => "Other Location",  :action => '/app/Search?type=location',  :icon => "/public/images/tabs/06-magnify.png" }, 
      { :label => "Settings",  :action => '/app/Settings',  :icon => "/public/images/tabs/19-gear.png" }, 
    ]
    @@tabbar = nil

    super

		@default_menu = {
      "Home" => :home, 
      "Settings" => :options,
#		"Log" => :log,
			"Close" => :close,
     }    
    # Uncomment to set sync notification callback to /app/Settings/sync_notify.
    # SyncEngine::set_objectnotify_url("/app/Settings/sync_notify")
    # SyncEngine.set_notification(-1, "/app/Settings/sync_notify", '')
  end

end
