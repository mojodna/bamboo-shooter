#!/usr/bin/env ruby -rubygems

require 'cgi'
require 'switchboard'
require 'eventmachine'
require 'em-http'
require 'xmpp4r'

module Bamboo
  class Shooter < Switchboard::Component
    attr_reader :component, :subscribers

    def initialize(settings)
      super(settings)
      @subscribers = {}
      @component = Jabber::Component.new(settings["component.domain"])

      on_presence(:presence_handler)
      on_iq(:iq_handler)
    end

    # override this if you want to do deferred sending (via queues or whatnot)
    def deliver(data)
      puts ">> #{data.to_s}" if debug?
      component.send(data)
    end

    def message(to, data)
      msg = Jabber::Message.new(to)
      msg.attributes["from"] = settings["component.domain"]
      msg.add(data)
      deliver(msg)
    end

    def publish(node, xml_node)
      event = Jabber::PubSub::Event.new
      items = Jabber::PubSub::EventItems.new
      items.node = node
      item = Jabber::PubSub::EventItem.new

      item.add(xml_node)
      items.add(item)
      event.add(items)

      (subscribers[node] || []).each do |subscriber|
        message(subscriber, event)
      end
    end

  protected

    def message_handler(message)
      # don't do anything here, but if / when we want to handle messages, do it here.
    end

    def presence_handler(presence)
      case presence.type
      when :error

        puts "An error occurred: #{presence.to_s}"

      when :probe
        # client is probing us to see if we're online

        # send a basic presence response
        p = Jabber::Presence.new
        p.to = presence.from
        p.from = presence.to
        p.id = presence.id
        p.status = settings["component.status"]
        deliver(p)

      when :subscribe
        # client has subscribed to us

        # First send a "you're subscribed" response
        p = Jabber::Presence.new
        p.to = presence.from
        p.from = presence.to
        p.type = :subscribed
        p.id = presence.id
        deliver(p)

        # follow it up with a presence request
        p = Jabber::Presence.new
        p.to = presence.from
        p.from = presence.to
        p.id = rand(2**32)
        p.status = FIRE_EAGLE_CONFIG.jabber_status
        deliver(p)

        # Then send a "please let me subscribe to you" request
        p = Jabber::Presence.new
        p.to = presence.from
        p.from = presence.to
        p.type = :subscribe
        p.id = rand(2**32)
        deliver(p)

      when :subscribed
        # now we've got a mutual subscription relationship
      when :unavailable
        # client has gone offline

        update_presence("unavailable", presence.from)

      when :unsubscribe
        # client wants to unsubscribe from us

        # send a "you're unsubscribed" response
        p = Jabber::Presence.new
        p.to = presence.from
        p.from = presence.to
        p.type = :unsubscribed
        p.id = presence.id
        deliver(p)

      when :unsubscribed
        # client has unsubscribed from us
      else

        # client is available
        update_presence((presence.show || :online).to_s, presence.from)

      end
    end

    def iq_handler(iq)
      if iq.pubsub
        if subscribe = iq.pubsub.first_element("subscribe")
          node = subscribe.attributes["node"]

          puts "Subscription to #{node} requested by #{iq.from}"
          subscribers[node] ||= []
          subscribers[node] << iq.from.strip unless subscribers[node].include?(iq.from.strip)

          resp = Jabber::Iq.new(:result, iq.from)
          resp.from = iq.to # TODO component.domain (elsewhere, too)
          resp.id = iq.id
          pubsub = Jabber::PubSub::IqPubSub.new
          subscription = Jabber::PubSub::Subscription.new(iq.from.strip, node)
          subscription.state = "subscribed"
          pubsub.add(subscription)
          resp.add(pubsub)

          deliver(resp)
        elsif unsubscribe = iq.pubsub.first_element("unsubscribe")
          node = unsubscribe.attributes["node"]

          puts "Unsubscription from #{node} requested by #{iq.from}"
          subscribers[node] ||= []
          subscribers[node].delete(iq.from.strip)

          resp = Jabber::Iq.new(:result, iq.from)
          resp.from = iq.to # TODO component.domain (elsewhere, too)
          resp.id = iq.id
          deliver(resp)
        else
          puts "Received a pubsub message"
          puts iq.to_s
          # TODO not-supported
          not_implemented(iq)
        end
      else
        # unrecognized iq
        not_implemented(iq)
      end
    end

    def update_presence(presence, jid)
    end

    # respond to a request by claiming that it's not implemented
    def not_implemented(iq)
      resp = iq.answer
      resp.type = :error
      resp.add(Jabber::ErrorResponse.new("feature-not-implemented"))
      deliver(resp)
    end
  end
end

SETTINGS = YAML.load(File.read("bamboo_shooter.yml"))

EM.run do
  Thread.new do
    @shooter = Bamboo::Shooter.new(SETTINGS)
    @shooter.run!
  end

  check_pandas = lambda do
    params = {
      'api_key' => SETTINGS["flickr.key"],
      'method' => 'flickr.panda.getPhotos'
    }

    ["ling ling", "hsing hsing", "wang wang"].each do |panda|
      http = EventMachine::HttpRequest.new('http://api.flickr.com/services/rest/').get(:query => params.merge('panda_name' => panda))

      http.callback do
        begin
          doc = REXML::Document.new(http.response)
          doc.root.each_element do |rsp|
            total = rsp.attributes["total"].to_s.to_f
            panda = rsp.attributes["panda"].to_s
            interval = rsp.attributes["interval"].to_s.to_f
            interval = interval / total
            delay = 0.0

            puts "#{panda} found #{total} items with a #{interval}s delay."

            rsp.each_element do |node|
              EventMachine::add_timer(delay) do
                @shooter.publish("/flickr/pandas/#{CGI.escape(panda)}", node)
              end
              delay += interval
            end
          end
        rescue REXML::ParseException
        end
      end
    end
  end

  EventMachine::add_periodic_timer(61, &check_pandas)
  check_pandas.call

  trap(:INT) do
    EM.stop_event_loop
  end
end
