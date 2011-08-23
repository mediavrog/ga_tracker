require 'cgi'
require 'digest'
require 'open-uri'

class GATracker

  attr_accessor :params, :request, :visitor_id

  def initialize(request, params, use_ssl=false)
    self.request = request.dup
    self.params = params.dup
    self.utm_location = (use_ssl ? 'https://ssl' : 'http://www') + UTM_GIF_LOCATION
    self.utm_params = utm_query_params
  end

  def set_custom_var(index, name, value, scope=nil)
    # update a custom var parameter
    utm_params[:utme].set_custom_variable(index, name, value, scope)
  end

  def track_event(category, action, label=nil, value=nil)
    # update a custom var parameter
    utm_params[:utme].set_event(category, action, label, value)

    # make google request
    request_google utm_params
  end

  def track_page_view(path=nil)
    request_google utm_params
  end

  protected

  attr_accessor :utm_location, :utm_params

  # Generate a visitor id for this hit.
  # If there is a visitor id in the cookie, use that, otherwise
  # use the guid if we have one, otherwise use a random number.
  def get_visitor_id(guid, account, user_agent, cookie)
    # if there was a visitor id set manually, use it
    return visitor_id unless (visitor_id.nil? || visitor_id.empty?)

    # If there is a value in the cookie, don't change it.
    return cookie unless (cookie.nil? || cookie.empty?)

    message = ""
    unless (guid.nil? || guid.empty?)
      # Create the visitor id using the guid.
      message = guid + account
    else
      # otherwise this is a new user, create a new random id.
      #message = useragent + uniqid(getrandomnumber(), true)
      message = user_agent + get_random_number.to_s
    end

    md5string = Digest::MD5.hexdigest(message)

    "0x" + md5string[0, 16]
  end

  private

  # seems to be the current version
  # just search for 'utmwv' in http://www.google-analytics.com/ga.js
  VERSION = "5.1.5"
  COOKIE_NAME = "__utmmobile"
  COOKIE_PATH = "/"

  # Two years in seconds.
  COOKIE_PERSISTENCE = 63072000
  UTM_GIF_LOCATION = ".google-analytics.com/__utm.gif"

  # The last octect of the IP address is removed to anonymize the user.
  def get_ip(remote_address)
    return '' if (remote_address.nil? || remote_address.blank?)

    # Capture the first three octects of the IP address and replace the forth
    # with 0, e.g. 124.455.3.123 becomes 124.455.3.0
    remote_address.to_s.gsub!(/([^.]+\.[^.]+\.[^.]+\.)[^.]+/, "\\1") + "0"
  end

  def utm_query_params
    #timestamp = Time.now.utc.strftime("%H%M%S").to_i

    domain_name = (request.env["SERVER_NAME"].nil? || request.env["SERVER_NAME"].blank?) ? "" : request.env["SERVER_NAME"]

    # Get the referrer from the utmr parameter, this is the referrer to the
    # page that contains the tracking pixel, not the referrer for tracking
    # pixel.
    document_referer = params[:utmr]
    if (document_referer.nil? || (document_referer.empty? && document_referer != "0"))
      document_referer = "-"
    else
      document_referer = CGI.unescape(document_referer)
    end
    document_path = params[:utmp].blank? ? "" : CGI.unescape(params[:utmp])

    account = params[:utmac].blank? ? "ua-1" : params[:utmac]
    user_agent = (request.env["HTTP_USER_AGENT"].nil? || request.env["HTTP_USER_AGENT"].empty?) ? "" : request.env["HTTP_USER_AGENT"]

    # Try and get visitor cookie from the request.
    cookie = nil #cookies[COOKIE_NAME]

    visitor_id = get_visitor_id(request.env["HTTP_X_DCMGUID"], account, user_agent, cookie)

    # Always try and add the cookie to the response.
    #request.cookies[COOKIE_NAME] = { :value => visitor_id, :expires => COOKIE_PERSISTENCE.to_i + timestamp, :path => COOKIE_PATH }

    # Construct the gif hit url params
    {
        :utmwv => VERSION,
        :utmn => rand(0x7fffffff).to_s,
        :utmhn => CGI.escape(domain_name),
        :utme => UTME.new,
        :utmr => CGI.escape(document_referer),
        :utmp => CGI.escape(document_path),
        :utmac => account,
        :utmcc => '__utma%3D999.999.999.999.999.1%3B',
        :utmvid => visitor_id,
        :utmip => get_ip(request.env["REMOTE_ADDR"])
    }
  end

  # Make a tracking request to Google Analytics from this server.
  # Copies the headers from the original request to the new one.
  # If request containg utmdebug parameter, exceptions encountered
  # communicating with Google Analytics are thown.
  def request_google(params)
    utm_url = @utm_location + "?" + params.to_query

    puts "--------sending request to GA-----------------------"
    puts utm_url
    #open(utm_url, "User-Agent" => request.env["HTTP_USER_AGENT"],
    #     "Header" => ("Accepts-Language: " + request.env["HTTP_ACCEPT_LANGUAGE"]))
  end

end

require 'ga_tracker/utme'