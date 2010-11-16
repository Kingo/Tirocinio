module Scraper
  ##Questa classe si prende carico:
  # Per ogni profilo:
  # - interrogare le fonti associate
  # - per ogni fonte :
  #   - recupera le pagine dalla pagina di ricerca
  
  class Crawler 
    class << self
      def run(args)
        
        queue = Array.new
        scrapers = []
        
        if args[:profiles] then
          args[:profiles].each do |profile_id|
            scrapers = Scrape.find_all_by_profile_id(profile_id)
            if args[:ignore_profiles] then
              args[:profiles].each do |ignore_profile_id|
                scrapers.delete_if { |scraper| scraper.profile_id ==  ignore_profile_id }
              end  
            end                              
          end
        else
          scrapers = Scrape.not_expireds        
        end
        if args[:scrapes] then
          scrapers.delete_if { |scraper| !args[:scrapes].include? scraper.id  }
        end
        scrapers.each do |scrape|
          begin
            source    = scrape.source
            profile   = scrape.profile
            
            if scrape.keywords.blank? then
              keywords  = profile.keywords
            else
              keywords  = scrape.keywords
            end
            keywords.each do |keyword|
              Scraper.logger.info "Start checking scraper of #{source.url} (#{source.id}) - #{profile.title} (#{profile.id}) - keyword #{keyword} - scraper #{source.filename}"
              #elimina i risultati doppi
              results = source.scraper({:keywords => keyword}).uniq.compact
              Scraper.logger.info "Found #{results.size} results for source #{source.url} (#{source.id}) - #{profile.title} (#{profile.id}) - keyword #{keyword}"
              # add links from this document to the queue
              results.each do |result| 
                Scraper.logger.info "Creating page form result #{result[:url]}"
                result = result.merge({:referring_uri => source.url, :profile_id => profile.id, :referring_source_id => source.id})
                doc = Document.create(result)
                Scraper.logger.info "Adding page to queue #{result[:url]}"
                queue << doc unless doc.nil?
              end
            end
          rescue Exception => e
            Scraper.logger.error( "Scraper exception #{e}")
            Scraper.logger.error("Error processing source #{source.uri.to_s}: #{$!}")
            Scraper.logger.error("Trace: #{$!.backtrace.join("\n")}")
          ensure
            scrape.advance          
          end

        end
        Scraper.logger.info "Return queue #{queue.size}"
        return queue
      end
    end
  end
end