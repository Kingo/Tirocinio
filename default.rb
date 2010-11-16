begin
  require 'nokogiri'
rescue LoadError
  require 'rubygems'
  require 'nokogiri'
end

if defined?(Nokogiri)
  module Scraper
    module ContentExtractors
      class NokogiriDefaultContentExtractor < NokogiriContentExtractor
        #Default extractor, return title and body content
      end
    end
  end
end