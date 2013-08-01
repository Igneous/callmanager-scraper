#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'

scriptdir = File.dirname(File.expand_path $0)
Daemons.run_proc('shitscraper.rb', {:dir_mode => :normal, :dir => "/var/spool/scraper"}) do
  Dir.chdir(scriptdir)
  exec "ruby shitscraper.rb"
end
