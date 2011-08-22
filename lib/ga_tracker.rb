require 'cgi'
require 'digest'
require 'open-uri'

class GATracker

  attr_accessor :request, :params

  def initialize(request, params, use_ssl=false)
    @request = request.dup
    @params = params.dup
    @utm_location = (use_ssl ? 'https' : 'http') + '://' + UTM_GIF_LOCATION
  end

  def set_custom_var(index, name, value, scope=nil)
    # update a custom var parameter
  end

  def track_event(category, action, label=nil, value=nil)
    params = utm_url_params

    # add/modify event parameter


    # make google request
    request_google params
  end

  def track_page_view(path=nil)
    request_google utm_url_params
  end

  protected

  # Generate a visitor id for this hit.
  # If there is a visitor id in the cookie, use that, otherwise
  # use the guid if we have one, otherwise use a random number.
  def get_visitor_id(guid, account, user_agent, cookie)
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

  # Tracker version.
  VERSION = "4.4sh"
  COOKIE_NAME = "__utmmobile"
  COOKIE_PATH = "/"

  # Two years in seconds.
  COOKIE_PERSISTENCE = 63072000
  UTM_GIF_LOCATION = "www.google-analytics.com/__utm.gif"

  # The last octect of the IP address is removed to anonymize the user.
  def get_ip(remote_address)
    return '' if (remote_address.nil? || remote_address.blank?)

    # Capture the first three octects of the IP address and replace the forth
    # with 0, e.g. 124.455.3.123 becomes 124.455.3.0
    remote_address.to_s.gsub!(/([^.]+\.[^.]+\.[^.]+\.)[^.]+/, "\\1") + "0"
  end

  def utm_query_params
    timestamp = Time.now.utc.strftime("%H%M%S").to_i

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
    cookie = cookies[COOKIE_NAME]

    visitor_id = get_visitor_id(request.env["HTTP_X_DCMGUID"], account, user_agent, cookie)

    # Always try and add the cookie to the response.
    request.cookies[COOKIE_NAME] = { :value => visitor_id, :expires => COOKIE_PERSISTENCE.to_i + timestamp, :path => COOKIE_PATH }

    # Construct the gif hit url params
    {
        :utmwv => VERSION,
        :utmn => rand(0x7fffffff).to_s,
        :utmhn => CGI.escape(domain_name),
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

    #puts "--------sending request to GA-----------------------"
    #puts utmurl
    open(utm_url, "User-Agent" => request.env["HTTP_USER_AGENT"],
         "Header" => ("Accepts-Language: " + request.env["HTTP_ACCEPT_LANGUAGE"]))
  end


end

class GATracker::UTME

  Event = Struct.new(:category, :action, :opt_label, :opt_value) do
    def to_s
      output = "5(#{category}*#{action}"
      output += "*#{opt_label}" if opt_label
      output += ")"
      output += "(#{opt_value})" if opt_value
      output
    end
  end

  CustomVariable = Struct.new(:name, :value, :opt_scope) do
    def to_s
      bang = "#{slot != 1 ? "#{slot}!" : ''}"
      output = "8(#{bang}#{name})9(#{bang}#{value})"
      output += "11(#{bang}#{opt_scope})" if opt_scope
      output
    end
  end

  class CustomVariables

    @@valid_keys = 1..5

    def initialize
      @contents = { }
    end

    def set_custom_variable(slot, custom_variable)
      return false if not @@valid_keys.include?(slot)
      @contents[slot] = custom_variable
    end

    def unset_custom_variable(slot)
      return false if not @@valid_keys.include?(slot)
      @contents.delete(slot)
    end

    # follows google custom variable format
    # best explained by examples
    #
    # 1)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # ==> 8(foo)9(bar)11(1)
    #
    # 2)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # pageTracker._setCustomVar(2,"bar", "vok", 3)
    # ==> 8(foo*bar)9(val*vok)11(1*3)
    #
    # 3)
    # pageTracker._setCustomVar(1,"foo", "val", 1)
    # pageTracker._setCustomVar(2,"bar", "vok", 3)
    # pageTracker._setCustomVar(4,"baz", "vol", 1)
    # ==> 8(foo*bar*4!baz)9(val*vak*4!vol)11(1*3*4!1)
    #
    # 4)
    # pageTracker._setCustomVar(4,"foo", "bar", 1)
    # ==> 8(4!foo)9(4!bar)11(4!1)
    #
    def to_s
      return '' if @contents.empty?

      ordered_keys = @contents.keys.sort
      names = values = scopes = ''

      ordered_keys.each do |slot|
        custom_variable = @contents[slot]
        predecessor = @contents[slot-1]

        has_predecessor = !!predecessor
        has_scoped_predecessor = !!predecessor.try(:opt_scope)

        star = names.empty? ? '' : '*'
        bang = (slot == 1 || has_predecessor) ? '' : "#{slot}!"

        scope_star = scopes.empty? ? '' : '*'
        scope_bang = (slot == 1 || has_scoped_predecessor) ? '' : "#{slot}!"

        names += "#{star}#{bang}#{custom_variable.name}"
        values += "#{star}#{bang}#{custom_variable.value}"
        scopes += "#{scope_star}#{scope_bang}#{custom_variable.opt_scope}" if custom_variable.opt_scope
      end

      output = "8(#{names})9(#{values})"
      output += "11(#{scopes})" if not scopes.empty?
      output
    end

  end

  def initialize
    @custom_variables = CustomVariables.new
  end

  def set_event(category, action, label=nil, value=nil)
    @event = Event.new(category, action, label, value)
    self
  end

  def set_custom_variable(slot, name, value, scope=nil)
    @custom_variables.set_custom_variable(slot, CustomVariable.new(name, value, scope))
    self
  end

  def unset_custom_variable(slot)
    @custom_variables.unset_custom_variable(slot)
    self
  end

  def to_s
    @event.to_s + @custom_variables.to_s
  end

end