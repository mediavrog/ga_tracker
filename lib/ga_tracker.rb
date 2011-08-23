require 'open-uri'

class GATracker

  def initialize(params, use_ssl=false)
    @utm_params = extend_with_default_params(params)
    @utm_location = (use_ssl ? 'https://ssl' : 'http://www') + UTM_GIF_LOCATION
  end

  def track

    utm_url = @utm_location + "?" + @utm_params.to_query

    puts "--------sending request to GA-----------------------"
    puts utm_url
    open(utm_url)

    # reset events / custom variables here
    @utm_params.delete(:utme)
  end

  def track_event(category, action, label=nil, value=nil)
    @utm_params[:utme].set_event(category, action, label, value)
    track
  end

  def track_page_view(path=nil)
    @utm_params.merge({ :utmp => path }) if path
    track
  end

  def set_custom_variable(index, name, value, scope=nil)
    @utm_params[:utme].set_custom_variable(index, name, value, scope)
  end

  def unset_custom_variable(index)
    @utm_params[:utme].unset_custom_variable(index)
  end

  class << self
    attr_accessor :account_id
  end

  private

  # seems to be the current version
  # search for 'utmwv' in http://www.google-analytics.com/ga.js
  VERSION = "5.1.5"
  UTM_GIF_LOCATION = ".google-analytics.com/__utm.gif"

  # adds default params
  def extend_with_default_params(params)
    params.reverse_merge({
                             :utme => Utme.parse(params[:utme]),
                             :utmwv => VERSION,
                             :utmn => rand(0x7fffffff).to_s,
                             :utmac => GATracker.account_id
                         })
  end

end

require 'ga_tracker/utme'