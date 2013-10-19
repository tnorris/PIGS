# PIGSServer.rb
# Simple HTTP server that routes our PUT requests

require 'rubygems'
require 'webrick'
require File.dirname(__FILE__) + '/PIGSTuner'
require File.dirname(__FILE__) + '/PIGSRoutes'

if ARGV[0] then
  port = ARGV[0]
else
  port = 9001
end

if $0 == __FILE__ then

  # Create the server
  mime_types = WEBrick::HTTPUtils::DefaultMimeTypes
  mime_types.store 'js', 'application/javascript'
  server = WEBrick::HTTPServer.new(
      :Port => port,
      :MimeTypes => mime_types,
  )

  server.config[:fish] = "hat"

  ip = IPSocket.getaddress(Socket.gethostname)

  # Create a tuner
  tuner = PIGSTuner.new

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
  puts "\n===================="
  puts " * PIGSServer running at #{ip} on port #{port}"
  puts "====================\n\n"

  server.start
end
