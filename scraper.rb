require 'rubygems'
require 'singleton'
require 'ostruct'
require 'open-uri'
require 'mechanize'
require 'logger'
require 'ferret'
require 'rtranslate'
require 'digest/md5'
require 'json'

# load libraries extractors
Dir["#{File.expand_path(File.dirname(__FILE__))}/lib/*.rb"].each do |f|
  begin
    require f 
  rescue LoadError
    Scraper.logger.error "could not load #{f}: #{$!}"
  end
end
require File.dirname(__FILE__) + '/lib/htmlentities/htmlentities'

$KCODE = 'u'
require 'jcode'



module Scraper

  #class Scraper
  class << self
    # the filter chains are for limiting the set of indexed documents.
    # there are two chain types - one for http, and one for file system
    # crawling.
    # a document has to survive all filters in the chain to get indexed.
    def filter_chain
      @filter_chain ||= {
        # filter chain for http crawling
        :http => [
          :scheme_filter_http,
          :fix_relative_uri,
          :normalize_uri,
          { :hostname_filter => :include_hosts },
          { Scraper::UrlFilters::UrlInclusionFilter => :include_documents },
          { Scraper::UrlFilters::UrlExclusionFilter => :exclude_documents },
          Scraper::UrlFilters::VisitedUrlFilter 
        ]
      }
         
    end
    
    
    def logger
      logger_path            = (File.join(File.dirname(__FILE__),"../../log/dev_scraper.log"))#ENV['RAILS_ENV'] == 'production' ? (File.join(File.dirname(__FILE__),"../../log/scraper.log")) : STDOUT
      @@logger               ||= Logger.new(logger_path,'daily',10*1024)
      @@logger.level         = ENV['RAILS_ENV'] == 'production' ? Logger::INFO : Logger::DEBUG
      @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      
      @@logger.formatter = proc{|s,t,p,m|"%5s [%s] %s :: %s\n" % [s, t.strftime("%Y-%m-%d %H:%M:%S"), p, m]}

      
      return @@logger
    end

    # RDig configuration
    #
    # may be used with a block:
    #   RDig.configuration do |config| ...
    #
    # see doc/examples/config.rb for a commented example configuration
    def configuration
      if block_given?
        yield configuration
      else
        @config ||= OpenStruct.new(
          :crawler           => OpenStruct.new(
            :include_documents => nil,
            :exclude_documents => nil,
            :index_document    => nil,
            :num_threads       => 10,
            :max_redirects     => 5,
            :wait_before_leave => 10,
            :wait_before_loop  => 16000
          ),
          :scraper           => OpenStruct.new(
            :source_path => "lib/scrapers/sources",
            :page_path => "lib/scrapers/pages"
          ),
          :comment_extraction  => OpenStruct.new(
            # settings for html comment extraction (hpricot)
            :wordpress      => OpenStruct.new(
              :title_tag_selector   => "title",
              :author_tag_selector  => "dc:creator",
              :content_tag_selector => "description",
              :url_tag_selector     => "guid",
              :published_tag_selector => "pubDate",
              :link_tag_selector => "link",
              :origlink_tag_selector => "feedburner:origLink"                  
            ),
            :blogger      => OpenStruct.new(
              :title_tag_selector   => "title",
              :author_tag_selector  => "author",
              :content_tag_selector => "content",
              :url_tag_selector     => "link",
              :published_tag_selector => "published"                 
            ),
            :typepad      => OpenStruct.new(
              :title_tag_selector   => "title",
              :author_tag_selector  => "dc:creator",
              :content_tag_selector => "description",
              :url_tag_selector     => "guid",
              :published_tag_selector => "pubDate"                
            )
          ),
          :content_extraction  => OpenStruct.new(
            # settings for html content extraction (hpricot)
            :config      => OpenStruct.new(
              :name => 'Scraper::ContentExtractors::NokogiriDefaultContentExtractor',
              :title_tag_selector => 'title', 
              :content_tag_selector => 'body'
            )
          )
        )
      end
    end
    alias config configuration   
  end
end