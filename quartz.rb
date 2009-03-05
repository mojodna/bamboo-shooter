#!/usr/bin/env ruby -rubygems

require 'socket'
require 'switchboard'

PANDAS = {
  "/flickr/pandas/ling+ling"   => 50000,
  "/flickr/pandas/hsing+hsing" => 50001,
  "/flickr/pandas/wang+wang"   => 50002
}

DEFAULTS = {
  "resource" => "quartz",
}

switchboard = Switchboard::Client.new(YAML.load(File.read("bamboo_shooter.yml")).merge(DEFAULTS))
switchboard.plug!(AutoAcceptJack, NotifyJack, PubSubJack)

switchboard.on_startup do
  defer :subscribed do
    PANDAS.keys.each do |node|
      puts "Subscribing to #{node}"
      subscribe_to(node)
    end
  end
end

switchboard.on_shutdown do
  PANDAS.keys.each do |node|
    puts "Unsubscribing from #{node}"
    unsubscribe_from(node)
  end
end

switchboard.on_pubsub_event do |event|
  event.payload.each do |payload|
    node = payload.attributes["node"]
    payload.elements.each do |item|
      photo = item.first_element("photo")

      udp = UDPSocket.new
      udp.connect("225.0.0.0", PANDAS[node])

      farm_id = photo.attributes["farm"]
      server_id = photo.attributes["server"]
      id = photo.attributes["id"]
      secret = photo.attributes["secret"]
      url = "http://farm#{farm_id}.static.flickr.com/#{server_id}/#{id}_#{secret}_m.jpg"

      # TODO how is this done with Array#pack?
      udp.send(url.split(//).collect { |c| "\0\0\0#{c}" }.join, 0)
    end
  end
end

switchboard.run!
