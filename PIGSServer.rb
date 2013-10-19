# PIGSServer.rb
# Simple HTTP server that routes our PUT requests

require 'rubygems'
require 'webrick'
require 'optparse'
require 'ostruct'
require 'logger'
log = Logger.new(STDOUT)
log.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] #{severity} #{progname}: #{msg}\n"
end


#require the tuner and routes
require File.dirname(__FILE__) + '/PIGSTuner'
require File.dirname(__FILE__) + '/PIGSRoutes'

#parse us some options, WOO!
options = OpenStruct.new
opts = OptionParser.new do |opts|
  opts.on('-p [PORT]', '--port [PORT]', 'Run WEBrick on [PORT]. (default: 9001)') do |p|
    options.port = p
  end

  opts.on('-b [BACKEND]', '--backend [BACKEND]', 'Path to [BACKEND] program to run (default: /usr/bin/mplayer)') do |b|
    options.backend = b
  end

  opts.on('-a [ARGUMENTS]', '--arguments [ARGUMENTS]', Array, 'Arguments to pass to the backend, PIGSURL will be substituted with the url to the song to play (default: -really-quiet,"PIGSURL")') do |a|
    options.arguments = a
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end
opts.parse!(ARGV)

# set some defaults
options.port ||= 9001
options.backend   ||=  '/usr/bin/mplayer'
options.arguments ||= %w(--really-quiet "PIGSURL")

if $0 == __FILE__ then

  # Create the server
  mime_types = WEBrick::HTTPUtils::DefaultMimeTypes
  mime_types.store 'js', 'application/javascript'
  server = WEBrick::HTTPServer.new(
      :Port => options.port,
      :MimeTypes => mime_types,
  )

  ip = IPSocket.getaddress(Socket.gethostname)

  options.log = log

  # Create a tuner
  tuner = PIGSTuner.new options

  # Define routes
  server.mount '/', WEBrick::HTTPServlet::FileHandler, './www/'
  server.mount '/lucky', PIGSRoutes::LuckyRoute, tuner
  server.mount '/control', PIGSRoutes::ControlsRoute, tuner
  server.mount '/search', PIGSRoutes::SearchRoute, tuner
  server.mount '/play', PIGSRoutes::PlayRoute, tuner

  # Handle interuptions
  trap "INT" do
    server.shutdown
  end

  # Start the server

  log.info('PIGSServer') { "PIGSServer running at #{ip} on port #{options.port}" }

  server.start
end
