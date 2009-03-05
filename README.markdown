## Bamboo Shooter

A panda walks into a bar. He sits down next to a woman in a bikini, starts up
a conversation about sports and takes a sip of his beer, ignoring the woman in
preference to the gallery show that's being set up around him. After a little
while, he orders another beer and a plate of nachos. Eventually, he stands up,
walks towards the door, and turns around. He pulls a small revolver out of his
pocket, briefly aims, and nails the bartender between the eyes. That done, he
turns back around and ambles out of the bar.

### What is it?

Bamboo Shooter is an XMPP PubSub interface to the Flickr Pandas.

### How does it work?

There are a set of EventMachine timers that trigger polling of Ling Ling,
Hsing Hsing, and Wang Wang every minute. The data returned in those feeds is
parsed and fed through the shooter (a PubSub component using Switchboard),
evenly distributed time-wise.

### What eats Bamboo other than a Panda?

Subscribe to Wang Wang (he likes maps):

    $ switchboard --jid client@xmpp-server --password pa55word \
        pubsub --server bamboo.mojodna.net \
        subscribe --node "/flickr/pandas/wang+wang"

Unsubscribe:

    $ switchboard --jid client@xmpp-server --password pa55word \
        pubsub --server bamboo.mojodna.net \
        unsubscribe --node "/flickr/pandas/wang+wang"

Listen for events:

    $ switchboard --jid client@xmpp-server --password pa55word \
        pubsub --server bamboo.mojodna.net \
        listen

Alternately, use one of the clients that handles subscriptions.

Open Google Earth and get spun around as Wang Wang notices newly geo-tagged
photos:

    $ ./earth.rb "wang wang"

Open `Image Viewer.qtz` in Quartz Composer (included with OS X Developer
Tools) and watch photos in real-time:

    $ ./quartz.rb

### Requirements

EventMachine, rb-appscript, switchboard, and em-http-request are dependencies:

    $ sudo gem install eventmachine
    $ sudo gem install rb-appscript
    $ sudo gem install mojodna-switchboard -s http://gems.github.com/
    $ sudo gem install igrigorik-em-http-request -s http://gems.github.com/

### Random Issues

The Panda APIs don't return Atom, so you get `<photo/>` items instead.

Presence isn't tracked, so if you go offline, you will continue to receive
(lots of) events.

Subscriptions don't persist, so if the component is restarted, your
subscription will have been cleared.
