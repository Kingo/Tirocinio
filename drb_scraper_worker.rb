ENV['RAILS_ENV'] ||= 'development'
require File.dirname(__FILE__) + '/../../config/environment.rb'
require File.dirname(__FILE__) + '/../scraper/scraper'
require 'logger'


class DrbScraperWorker


  def initialize(args = nil)
    #Scraper.logger = Logger.new(STDOUT)
    #Scraper.logger.debug "Initialized scraper: #{Time.now}"
    #add_periodic_timer(Scraper.config.crawler.wait_before_loop) { run }
    #self.run
  end

  def crawl(args = {})
    Scraper.logger.info "Starting crawler: #{Time.now}"
    result = Scraper::Crawler.run(args)
    Scraper.logger.info("Stopping crawler: #{Time.now} with #{result.nil? ? 0 : result.size} result(s)")
    return result
  end
  
  
  def filter(args)
    Scraper.logger.info "Starting filter: #{Time.now}"
    result = Scraper::Filter.run(args)
    Scraper.logger.info "Stopping filter: #{Time.now} with #{result.nil? ? 0 : result.size} result(s)" 
    return result   
  end
  
  def fetch(args)
    Scraper.logger.info("Starting fetcher: #{Time.now}")
    result = Array.new()
    args.each do |document|
      begin
        if(document.respond_to? :fetch) then
          result << document if(document.fetch == :success)
        end
      rescue Exception => e
        Scraper.logger.error "Fetch error: #{e.inspect}"
        Scraper.logger.error "#{document.inspect}"
      end    
    end if( args.respond_to? :each)
    Scraper.logger.info("Stopping fetcher with: #{Time.now} #{result.nil? ? 0 : result.size} result(s)")    
    return result
  end
  
  def index(args)
    Scraper.logger.info("Starting indexer: #{Time.now}")
    result = Scraper::Indexer.run(args)
    Scraper.logger.info("Stopping indexer with: #{Time.now} #{result.nil? ? 0 : result.size} result(s)")
    return result
  end
  
  def analyze(args)
    Scraper.logger.info("Starting analyzer: #{Time.now}")
    result = Scraper::Analyzer.run(args)
    Scraper.logger.info("Stopping analyzer with: #{Time.now} #{result.nil? ? 0 : result.size} result(s)")
    return result
  end
  
  def alert(args)
    Scraper.logger.info("Starting alert: #{Time.now}")
    result = Scraper::Alert.run(args)
    Scraper.logger.info("Stopping alert with: #{Time.now} #{result.nil? ? 0 : result.size} result(s)")
    return result
  end  

  def finalize(args)
    Scraper.logger.info("Starting finalizer: #{Time.now}")
    result = Scraper::Finalizer.run({:days => 60})
    Scraper.logger.info("Stopping finalizer : #{Time.now}")
    return result
  end
  
  def run
    starting_time = Time.now
    Scraper.logger.info("Starting time: #{starting_time}")
    Profile.not_expireds.each do |profile|
      Scraper.logger.info("Starting with profile: #{profile.id} - #{profile.title}")
      result = crawl(:profiles => [profile.id])
      result = filter(result)
      result = fetch(result)
      result = index(result)
      #result = analyze(result)
      result = alert({:recipients => 2,:profiles => [profile.id]})
      result = finalize(result)
      Scraper.logger.info("Stopping with profile: #{profile.id} - #{profile.title}")
    end
    Scraper.logger.info("Elapsed time: #{Time.now - starting_time}")
  end
end

x = DrbScraperWorker.new
x.run
