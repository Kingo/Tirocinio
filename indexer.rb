require File.join(File.dirname(__FILE__),'language_detector')

module Scraper 
  class Indexer
    class << self
      def run(args={})
        @dateParser  = DateParser.new()
        @source_urls = UrlSet.new
        @source_urls.merge(Source.find(:all).map { |source| source.url })        
              
        return nil if args.nil?
        result = []
        args.each do |page|
          begin
            Scraper.logger.debug "Adding page to process: #{page.url}" 
            result << self.add(page)
          rescue Exception => e
            Scraper.logger.error "Fetch error: #{e.inspect}"  
          end
        end
        #ricrea l'indice
        #Page.rebuild_index
        result = result.compact
      end

      def add(doc)
        return nil if doc.uri.nil? 
        return nil if doc.uri.blank? 
        #controllare se il doc esiste già
        source = self.process_source(doc)  
        return nil    if source.nil? || source.id.nil?
        page  = self.process_page(doc,source)
        #page  = self.process_comments(doc,page) 
        return page
      end 

      def process_source(doc)
        Scraper.logger.info"Processing source #{doc.host}"
        url = URI.parse(doc.host).to_s

        if @source_urls.apply(url) then
          Scraper.logger.info"Source not found #{doc.host}"
          source = Source.create(:url => url.to_s)
          begin
            fillerchain = SiteFillers::FillerChain.new([:source_site_filler,:source_pagerank_filler])      
            fillerchain.apply(source)                
          rescue Exception => e
            Scraper.logger.error "Generic fillerchain exception: #{e.inspect}"  
          ensure    
            source.save  
          end
        else
          source = Source.find_by_url(url.to_s) 
        end
      rescue URI::Error => e
        Scraper.logger.error "Bad uri: #{doc.host} #{e}"  
      rescue Exception => e
        Scraper.logger.error "Generic error: #{e}"  
      ensure
        return source
      end


      def process_page(doc,source)
        page        = Page.find_or_initialize_by_url(doc.uri.to_s)
        profile     = Profile.find(doc.profile_id)

        if(doc == nil) then 
          raise "Doc is nil" 
        end

        #se la pagina esiste già esce dal processo  
        #unless page.new_record? then return page end
        if doc.content[:published].nil? then
          page_published = @dateParser.parse(doc.body)
        else
          page_published = @dateParser.parse(doc.content[:published])
        end

        if doc.content[:updated].nil? then
          page_updated   ||= page_published         
        else
          page_updated = doc.content[:updated].to_datetime
        end

        if page.new_record? then
          attributes = {}
          Scraper.logger.debug("Page is new")
          attributes[:author] = doc.content[:author]

          if doc.body.nil? then
            Scraper.logger.error"Content is empty: #{doc.url}"
          else
            attributes[:content] = doc.body.strip_all
          end

          if doc.title.nil? then
            Scraper.logger.error"Title is empty: #{doc.url}"
          else
            attributes[:title] = doc.title.strip_all
          end

          attributes[:links] = filter_links(doc.links,source.url)
          attributes[:source_id] = source.id
          attributes[:profile_id] = profile.id
          attributes[:referring_source_id] = doc.referring_source_id
          attributes[:etag] = doc.etag
          attributes[:raw] = doc.raw
          attributes[:published] = page_published

          if source.lang then
            attributes[:lang] = source.lang
          else
            attributes[:lang] = detect_lang(doc.url)
          end

          unless profile.languages.nil? || profile.languages.empty? then
            #filtra per lingua, se sono impostate sul profilo
            Scraper.logger.info"Profile #{profile.id} has language filter on #{profile.str_languages_label}"
            unless attributes[:lang].nil? then
              Scraper.logger.info("Page #{page.id} has language #{attributes[:lang]}")
              #controlla che sia impostata la lingua per la pagina, altrimenti lascia perdere
              unless profile.languages.include?(attributes[:lang]) then
                Scraper.logger.info"Profile #{profile.id} and page #{page.id} language doesn't match"
                attributes[:status] = 50
              end
            end
          end

          update = false

          if(update = page.update_attributes(attributes)) then
            Scraper.logger.info"Page saved with id #{page.id}"
          else
            Scraper.logger.error("Page not saved")
          end
          Scraper.logger.error"Source not found #{doc.url}" if source.nil?
          Scraper.logger.error"Referring source not found #{doc.url}" if doc.referring_source_id.nil?
          page.save_cache             
        else 
          Scraper.logger.debug("Page is old")
        end

        #Attributi cambiati ogni volta
        #salva la valutazione
        Scraper.logger.info"Saving attributes that can change over time"

        if doc.content[:evaluation] then
          Scraper.logger.debug("Parsing evaluation")
          evaluation = parse_evaluation(doc.content[:evaluation])
          if page.evaluation != evaluation then
            Scraper.logger.debug"Evaluation saved #{evaluation}"
            page.update_attribute(:evaluation,evaluation) 
          end  
        end 

        #salva i tags
        if doc.content[:tags] then
          # TODO pericoloso fare il controllo così, trovare un sistema migliore
          new_tags = doc.content[:tags].split(",").map {|x| x.strip.downcase}.sort.join(", ")

          if page.cached_tag_list != new_tags then
            Scraper.logger.debug("Tags saved #{doc.content[:tags]}")
            old_tags = page.cached_tag_list.split(", ")
            new_tags = new_tags.split(", ")
            new_tags = old_tags + new_tags
            page.tag(new_tags.uniq.join(','))
          end
        end

        #salva commenti
        self.process_comments(doc,page)
        page.scraped

        return page
      end

      def process_comments(doc,page)
        return page if doc.nil?
        return page if doc.comments.nil?
        Scraper.logger.debug"Checking comments"
        has_new_comment = false
          
        dateParser = DateParser.new(page.published)
        doc.comments.each do |comment|
          Scraper.logger.debug { "#{comment[:author]}" }
          comment_published = dateParser.parse(comment[:published])
          unless (comment[:content].blank? and comment[:title].blank?) then
            page_comment = page.comments.find_or_initialize_by_content( comment[:content])
            if page_comment.new_record? then
              Scraper.logger.debug("New comment")
              has_new_comment = true
              attributes = {}
              attributes[:author]     = comment[:author]
              attributes[:published]  = comment_published
              attributes[:title]      = comment[:title]
              if page_comment.update_attributes(attributes) then
                Scraper.logger.debug"Comment saved '#{page_comment.id}'"
              else
                Scraper.logger.error"Comment already present '#{page_comment.id}'"
              end
            end
          end
        end
        if has_new_comment then
          last_comment = page.comments.find(:first,:limit => 1, :order => "published DESC", :select => "published")
          page.update_attribute(:published, last_comment.published) if page.published != last_comment.published
        end
      rescue Exception => e
        Scraper.logger.error "Generic comment error: #{e}"
      ensure
        return page
      end

      def detect_lang(url)
        lang = nil
        Scraper.logger.debug"Detecting lang for url #{url}"
        language_detector = LanguageDetector.new(url)
        if language_detector then
          lang = language_detector.lang
          lang = "ot" if lang.nil?
          Scraper.logger.debug"Lang detected #{lang}"
        end
      rescue Exception => e
        Scraper.logger.error "Generic detect lang exception: #{e}"
      ensure
        return lang
      end

      def filter_links(links,url)
        return nil if links.nil?
        links.delete_if { |link| link =~ Regexp.new(Regexp.escape(url))}
      end


      def parse_evaluation(value)
        tmp = value.split("-")
        return nil if tmp[0].nil?
        value = tmp[0].gsub(/\W/,".").to_f
        base  = tmp[1].to_i || 5 #se non c'è la base la suppongo
        return nil if value.nil? || base.nil? || base == 0
        result = ((value * 5) / base).floor
        return result.to_i
      end
    end
  end

  class UrlSet
    include MonitorMixin
    def initialize()
      @urls = Set.new
      super
    end
    
    def merge(urls)
      @urls.merge(urls) unless urls.nil? || urls.empty?
    end
    
    def apply(url)
      synchronize do
        @urls.add?(url) ? url : nil
      end
    end
  end
end
