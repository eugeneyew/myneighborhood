require 'rho/rhoapplication'

class AppApplication < Rho::RhoApplication
  def initialize
    # Tab items are loaded left->right, @tabs[0] is leftmost tab in the tab-bar
    # Super must be called *after* settings @tabs!
    @tabs = [
      { :label => "Recent", :action => '/app/Search?type=recent', :icon => "/public/images/tabs/home_btn.png", :reload => true },
      { :label => "Nearby",  :action => '/app/Search?type=nearby',  :icon => "/public/images/tabs/122-stats.png" }, 
      { :label => "Other Location",  :action => '/app/Search?type=location',  :icon => "/public/images/tabs/07-map-marker.png" }, 
    ]
    @@tabbar = nil

    super
    
    # Uncomment to set sync notification callback to /app/Settings/sync_notify.
    # SyncEngine::set_objectnotify_url("/app/Settings/sync_notify")
    # SyncEngine.set_notification(-1, "/app/Settings/sync_notify", '')
  end

end
