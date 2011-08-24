Gem::Specification.new do |s|
  s.name        = 'ga_tracker'
  s.version     = '0.0.5'
  s.date        = '2011-08-24'
  s.summary     = "Server-side Google Analytics Tracker for Ruby on Rails"
  s.description = "Allows you to do server-side tracking for Google Analytics either using the given class or as a controller mix-in."
  s.authors     = ["Maik Vlcek"]
  s.email       = 'maik@mediavrog.net'
  s.files       = ['lib/ga_tracker.rb', 'lib/ga_tracker/utme.rb', 'lib/ga_controllers/tracking_controller.rb']
  s.homepage    = 'https://github.com/mediavrog/ga_tracker'
end
