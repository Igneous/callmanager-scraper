require 'watir-webdriver'
require 'nokogiri'
require 'headless'

class ShitscoScraper 

  # e.g ShitscoScraper.new :cucm_host => "172.20.1.15", :browser => :chrome
  def initialize(options = {})
    @hostname = options[:cucm_host]
    @browser  = Watir::Browser.new options[:browser]
  end

  # primarily for the convienience of debugging.. but also nice for .close and .goto
  def method_missing(meth, *args, &block)
    @browser.send meth, *args, &block 
  end

  # Logs into the cucm.
  # Options Hash requires :username, and :password.
  def login(options = {})
    @browser.goto 'https://' + @hostname + '/ccmadmin/showHome.do'
    @browser.text_field(:name => 'j_username').set options[:username]
    @browser.text_field(:name => 'j_password').set options[:password]
    @browser.button(:value => 'Login').click
    raise 'Unable to Login' unless @browser.text.include? 'Logout'
  end

  # Private method, so it doesn't get confused with list_phones..
  # Dumps table html of the result of searching "SEP" on the phone page.
  def get_phone_table
    @browser.goto @browser.link(:text => 'Phone').href
    @browser.text_field(:id => 'searchString0').set 'SEP'
    @browser.button(:value => 'Find').click
    # After we've made the initial request and gotten the results,
    # set the rows returned to an arbitrarily large number, so we can
    # display all the results on a single page.
    @browser.goto @browser.url + '&rowsPerPage=9999'

    return @browser.table(:summary => 'Find List Table Result').html
  end; private :get_phone_table

  # Calls get_phone_table, then parses the html and returns an array
  # of hashes (one hash per device).
  def list_phones
    phones = [] # We're going to push to this array momentarily.
    phonetable = Nokogiri::HTML(get_phone_table)
    
    # For each table row.
    phonetable.xpath('/html/body/table/tbody/tr').each do |row|
      # Working around an apparent nokogiri bug, where it still remembers
      # all of the elements matching //td from the previous doc..
      newrow = Nokogiri::HTML(row.to_s)

      # for all cells in the row, run "newrow.content" and map them to an array
      cols = newrow.xpath('//td').map(&:content)

      # if the status is registered, stick the phonehash in the phone array
      # also, special xpaths that aren't just plaintext.. might as well do it
      # here rather than testing for nil (again) outside of this..
      if not cols[6].nil? and cols[6].start_with? 'Registered'
        # Get the link destination of the column with the icon.
        uuid  = newrow.xpath('//td[starts-with(@id, "icon")]/a').attr('href').content
        # Assuming uuid is defined, grab UUID from the 'key=' get parameter.
        uuid &&= uuid.split('key=').last 
        # Scrape the alt-text of the phone icon to determine the model name.
        model = newrow.xpath('//td[starts-with(@id, "icon")]/a/img').attr('alt').content
        # Push all of this shit into the phones array.
        phones << {
          :mac    => cols[2],
          :uuid   => uuid,
          :model  => model,
          :dscr   => cols[3],
          :status => cols[6],
          :ipaddr => cols[7]
        }
      end
    end

    return phones
  end

  def get_device_attributes(uuid)
    @browser.goto 'https://' + @hostname + '/ccmadmin/gendeviceEdit.do?key=' + uuid
    
    user_list = Nokogiri::HTML(@browser.select_list(:name => 'fkenduser').html)
    username = user_list.xpath('//option[@selected]').first
    username &&= username.content # if username not nil, set to username.content

    # Grab the "Associations Information" table on the lefthand side of the page
    assoc_info = Nokogiri::HTML(@browser.table(:summary => 'Associations').html)
    # map the second column of each row to an array, if and only if it is a line
    # i.e. extract 2600 from a string like "Line [1] - 2600 in Some Partition"
    dirnums = assoc_info.xpath('//td').map(&:content)
                    .select { |content| content =~ /Line \[\d\] - \d+ in/ }
                    .map    { |dn| dn.split('-').last
                                     .split('in').first
                                     .strip! }

    return { :uuid => uuid, :user => username, :dn => dirnums }
  end

end
