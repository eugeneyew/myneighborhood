require 'rho'
require 'rho/rhocontroller'
require 'rho/rhoerror'
require 'helpers/browser_helper'
require 'json'

class RecentController < Rho::RhoController
  include BrowserHelper
  def index
		NavBar.create :title => "Recent"
  	render # => index.erb
	end
end
