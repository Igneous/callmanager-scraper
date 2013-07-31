require 'watir-webdriver'
require 'nokogiri'

class ShitscoScraper 

  # Creates a new instance of ShitscoScraper, then associates the Watir session
  # to an instance variable, "@browser".
  def initialize(options = {})
    unless options[:browser]
      @browser = Watir::Browser.new :firefox
    else
      @browser = Watir::Browser.new options[:browser]
    end
  end

  def method_missing(meth, *args, &block)
    @browser.send meth, *args, &block 
  end

  # Logs into the cucm form.
  # Options Hash requires :url (to showHome.do), :username, and :password.
  def login(options = {})
    @browser.goto options[:url]
    @browser.text_field(:name => 'j_username').set options[:username]
    @browser.text_field(:name => 'j_password').set options[:password]
    @browser.button(:value => 'Login').click
    raise 'Unable to Login' unless @browser.text.include? 'Logout'
  end

  def get_phone_table
    @browser.goto @browser.link(:text => 'Phone').href
    @browser.text_field(:id => 'searchString0').set 'SEP'
    @browser.button(:value => 'Find').click
    @browser.goto @browser.url + '&rowsPerPage=9999'

    return @browser.table(:summary => 'Find List Table Result').html
  end

  def list_phones
    phones = []
    phonetable = Nokogiri::HTML(get_phone_table)
    
    # For each table row.
    phonetable.xpath('/html/body/table/tbody/tr').each do |row|
      # Working around an apparent nokogiri bug, where it still remembers
      # all of the elements matching //td from the previous doc..
      newrow = Nokogiri::HTML(row.to_s)

      # for each row, run "row.content" and map them to an array
      cols = newrow.xpath('//td').map(&:content)

      # if the status is registered, stick the phonehash in the phone array
      # also, special xpaths that aren't just plaintext.. might as well do it
      # here rather than testing for nil (again) outside of this..
      if not cols[6].nil? and cols[6].start_with? 'Registered'
        phones << {
          :mac    => cols[2],
          :uuid   => newrow.xpath('//td[starts-with(@id, "icon")]/a').attr('href').content,
          :model  => newrow.xpath('//td[starts-with(@id, "icon")]/a/img').attr('alt').content,
          :dscr   => cols[3],
          :status => cols[6],
          :ipaddr => cols[7]
        }
      end
    end

    return phones
  end

  # FIX ME.. 
  def get_username(uuid)
    todo
  end

end
