#!/usr/bin/env ruby
path = File.expand_path $0
path = File.dirname(path)
require "#{path}/lib/scraper.rb"
require 'syck'

LOGIN_URL = "https://your.com/ccmadmin/showHome.do"
USERNAME  = "replaceme"
PASSWORD  = "replaceme"

if __FILE__ == $PROGRAM_NAME

  scraper = ShitscoScraper.new
  at_exit { scraper.close if scraper }

  scraper.login :url => LOGIN_URL,
                :username => USERNAME,
                :password => PASSWORD

  puts scraper.list_phones.to_yaml

end
