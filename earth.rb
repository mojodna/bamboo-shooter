#!/usr/bin/env ruby -rubygems

begin
  require 'appscript'
rescue LoadError => e
  gem = e.message.split("--").last.strip
  puts "The #{gem} gem is required."
end

require 'cgi'
require 'switchboard'

node = "/flickr/pandas/#{CGI.escape(ARGV[0])}"

earth = Appscript.app("Google Earth")

DEFAULTS = {
  "resource" => "earth",
}

switchboard = Switchboard::Client.new(YAML.load(File.read("bamboo_shooter.yml")).merge(DEFAULTS))
switchboard.plug!(AutoAcceptJack, NotifyJack, PubSubJack)

switchboard.on_startup do
  defer :subscribed do
    puts "Subscribing to #{node}"
    subscribe_to(node)
  end
end

switchboard.on_shutdown do
  puts "Unsubscribing from #{node}"
  unsubscribe_from(node)
end

switchboard.on_pubsub_event do |event|
  event.payload.each do |payload|
    payload.elements.each do |item|
      photo = item.first_element("photo")
      lat = photo.attributes["latitude"].to_f
      lon = photo.attributes["longitude"].to_f
      earth.SetViewInfo({:latitude => lat, :longitude => lon, :distance => (rand * 25000) + 5000, :azimuth => rand * 360, :tilt => (rand * 75)}, {:speed => 1})
    end
  end
end

switchboard.run!
