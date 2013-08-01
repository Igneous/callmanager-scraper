#!/usr/bin/env ruby
path = File.dirname(File.expand_path $0)
[ "#{path}/lib/scraper.rb", 'rubygems', 'sinatra', 'headless',
  'syck', 'bundler/setup' ].each { |gem| require gem }

# -- svc settings -- #
set :port, 8081
set :bind, '0.0.0.0'
set :environment, :production
HOSTNAME = "cucm01.your.com"
USERNAME  = "readonly-acct"
PASSWORD  = "hackme"

# scrape() starts up an Xvfb server via the headless gem,
# then spawns an instance of ShitscoScraper inside of it,
# logs in, and then yields to whatever block it was given.
# (and ensures that it tears down xvfb/chrome when done)
#
# I'd like to put this in ShitscoScraper somehow.. but
# I'm not not entirely sure the best way.. For the time
# being, it's here.
def scrape(&block)
    headless = Headless.new
    headless.start
    begin
      scraper = ShitscoScraper.new :cucm_host => HOSTNAME,
                                   :browser   => :chrome

      scraper.login :username => USERNAME,
            		    :password => PASSWORD

      yield(scraper)
    ensure
      scraper.close
      headless.destroy
    end
end

# No parameters required.. /phones/gets returns a yaml doc
# of all the phones.
#
# Returns an array of hashes, each hash representing a phone.
# Each hash contains the keys:
# :mac    (The MAC address of the device),
# :uuid   (The UUID of the device, according to CUCM),
# :model  (The (full) Model name of the device),
# :dscr   (Any Description information for the device),
# :status (Registration status of the device),
# :ipaddr (IP Address of the device)
get '/phones/get' do
    scrape do |scraper|
      return scraper.list_phones.to_yaml
    end
end

# device_attributes for the time being needs to be POSTed a
# yaml array called 'list'.. It should not be form/multipart
# encoded, just plaintext/urlencoded is all that's required.
#
# Returns an array of hashes; the hashes contain the keys:
# :uuid (the original uuid passed in),
# :user (the owner of the device assoc'd with the uuid),
# :dn   (an array of Extens assoc'd with the device)
post '/device_attributes/get' do
  scrape do |scraper|
    devices = []
    uuidlist = YAML.load(params[:list])

    uuidlist.each do |uuid|
      devices.push scraper.get_device_attributes(uuid)
    end

    return devices.to_yaml
  end
end
