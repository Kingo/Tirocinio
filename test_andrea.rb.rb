ENV['RAILS_ENV'] ||= 'development'
require File.dirname(__FILE__) + '/../../config/environment.rb'
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'timeout'
require File.join(File.dirname(__FILE__),'scraper')
require File.join(File.dirname(__FILE__),'whatlanguage')


$KCODE = 'UTF8'

doc = {:url => "http://cucina.liquida.it/focus/2010/09/14/dal-mcitaly-al-mozzarillo-il-nuovo-panino-made-in-italy-di-mcdonald-s/", :profile_id => 1052296639}
document = Scraper::HttpDocument.new(doc)
document.fetch
result = Scraper::Indexer.run([document])
#
#p result.inspect

p document.inspect

# =>  http://www.asphalto.org/go/post_id/1278369/page_start/150
# => http://cucina.liquida.it/focus/2010/09/14/dal-mcitaly-al-mozzarillo-il-nuovo-panino-made-in-italy-di-mcdonald-s/