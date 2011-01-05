require 'digest/md5'
require 'open-uri'

module  Scraper
  #
  # Document base class
  #
  class Document

    attr_reader :uri
    attr_reader :content
    attr_reader :content_type
    attr_reader :charset
    attr_reader :status
    attr_accessor :accessor_attributes
    attr_accessor :source_id
    attr_accessor :profile_id
    attr_accessor :referring_source_id
    attr_accessor :referring_uri

    def self.create(args)
      #Problem about url decode
      #uri = URI.parse(URI.encode(args[:url]))
      uri = URI.parse(args[:url])
      # a referrer is a clear enough hint to create an HttpDocument
      return HttpDocument.new(args) if uri && uri.scheme =~ /^https?$/i
    rescue URI::InvalidURIError
      Scraper.logger.error "Cannot create document using invalid URL: #{args[:url]}"
      return nil
    end

    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args)
      begin
        #@uri = URI.parse(URI.encode(args.delete(:url)))
        @uri = URI.parse(args.delete(:url))
        @source_id = args.delete(:source_id)
        @profile_id = args.delete(:profile_id)
        @referring_source_id = args.delete(:referring_source_id)
        @accessor_attributes = args
        @content = args
        @content ||= {}

      rescue URI::InvalidURIError
        Scraper.logger.error "Cannot create document using invalid URL: #{args[:url]}"
        return nil
      end
    end

    def url; @uri.to_s end
    def raw; @content[:raw] end
    def title; @content[:title] end
    def body; @content[:content] end
    def links; @content[:links] end
    def comments; @content[:comments] end

    def hashed_uri
      if @uri.blank? then
        return nil
      else
        return Digest::MD5.hexdigest(@uri.to_s)
      end
    end

    def is_fetched?
      (!title.blank? && !body.blank?)
    end

    def has_content?
      !self.content.nil?
    end

  end


  #
  # Remote Document to be retrieved by HTTP
  #
  class HttpDocument < Document

    attr_reader :referring_uri
    attr_reader :status
    attr_reader :etag

    # url: url of this document, may be relative to the referring doc or host.
    # referrer: uri of the document we retrieved this link from
    def initialize(args={})
      super(args)
      @referring_uri = args[:referring_uri]
      @user_agent = Useragent.new.rand_useragent
    end

    def host
      if @uri.nil? then
        return nil
      else
        return @uri.scheme + "://" + @uri.host + "/"
      end
    end


    def referring_host
      if @referring_uri.nil? then
        return nil
      else
        return @referring_uri.scheme + "://" + @referring_uri.host + "/"
      end
    end

    def fetch
      @status = :fail
      Scraper.logger.debug "Check page #{@uri.to_s}"
      #copia gli accessor_attributes direttamente
      @content = Hash.new if @content.nil?
      #potrebbe succedere che in alcuni casi speciali (vedi Youtube) la pagina non abbia bisogno di
      #essere fetchata perchè è già completa. Una pagina è completa se soddisfa i requisti del needs_indexing
      if self.is_fetched? then
        Scraper.logger.info "Page not fetching #{@uri.to_s}"
        @status = :success
        return @status
      else
        #open document
        Scraper.logger.info "Page fetching #{@uri.to_s}"
        self.open
        result = nil

        if(@status == :success) then
          #if get_scraper return nil try with readability and after if is null fetch all
          configs = []

          if custom_scraper = get_scraper then
            custom_scraper.config.name = 'Scraper::ContentExtractors::NokogiriContentExtractor'
            configs << custom_scraper
          end

          configs << OpenStruct.new(:config => OpenStruct.new(:url => @uri.to_s, :name => 'Scraper::ContentExtractors::Readability'))
          configs << Scraper.configuration.content_extraction #get default extractor


          configs.each do |config|
            Scraper.logger.debug "Page extracting content #{@uri.to_s}"
            result = self.extract(config)
            if (attributes(result)) then
              Scraper.logger.debug "Page  content extracted #{@uri.to_s}"
              break
            end
          end
          @status = :fail unless result
        end
      end
      if result then
        @status = :success
      else
        Scraper.logger.error "Impossible to fetch content of #{@uri.to_s}"
        @status = :fail
      end
      @status
    end


    protected

    #Merge all result
    def attributes(result)
      return nil if result.nil?
      @content.merge!(result)
      @accessor_attributes.each do |key,value|
        @content[key]= value
      end unless self.accessor_attributes.nil?
      @content[:title]    = @content[:title].nil? ? nil : @content[:title].decode_entities.strip_all
      Scraper.logger.debug("Getting title #{@content[:title]} for #{@uri.to_s}")
      @content[:content]  = @content[:content].nil? ? nil : @content[:content].decode_entities.strip_all
      Scraper.logger.debug("Getting content #{@content[:title]} for #{@uri.to_s}")
      return is_fetched? #non content.blank e non title.blank
    end

    def extract(config)
      Scraper.logger.debug("Getting scraper for #{self.uri.to_s}")
      return nil if config.nil?
      Scraper.logger.info("Fetching #{self.uri.to_s} for profile #{self.profile_id}")
      Scraper.logger.debug("Calling content extractor for content type #{@content_type} with config #{config} ")
      result = ContentExtractors.process(@content[:raw], @content_type, config)
    rescue
      Scraper.logger.error "Error fetching #{@uri.to_s}: #{$!}"
      result = nil
    ensure
      result
    end

    def extract_comments
      if @content[:comments].empty? then
        @content[:comments] = CommentExtractors.process(self, @generator)
        Scraper.logger.debug("Comments: Found #{@content[:comments].size} comments")  unless @content[:comments].nil?
      end
    rescue
      Scraper.logger.error "Error fetching comments for #{@uri.to_s}"
    end

    #Open html page, set etag, generator, content type and eventually lang present in meta tag
    def open
      @uri.open(  "User-Agent"=>@user_agent,
        "Accept-Charset"=>"utf-8"#,
        #"Connection"=>"Keep-Alive"
      ) do |doc|
        Scraper.logger.debug "Open document #{@uri.to_s} with status #{doc.status}"
        case doc.status.first.to_i
        when 200 #page found
          @etag = doc.meta['etag']
          @generator = doc.meta['generator']
          @charset = doc.charset

          # FIXME se vuoto ritorna sempre application/octet
          # Scraper.logger.debug "Content-Type not found for #{@uri.to_s}" unless @content_type
          @status = :success
          @content[:raw] = doc.read

          @content_type = doc.content_type

          if doc.content_type  == 'application/octet-stream' then
            if (@content[:raw] && @content[:raw].index('<!DOC') == 0) then
              @content_type = 'text/html'
            end
          end

          #try to find lang in header
          @lang   = doc.meta['languages'] || ''
          charsets = [@charset, "iso-8859-1", "UTF-8"]
          charsets.each do |ct|
            break if (iconv(ct))
          end
        when 404 #page not found
          Scraper.logger.error "got 404 for #{@uri}"
          @status = :fail
        else  #another page/server error.
          Scraper.logger.error "don't know what to do with response: #{doc.status.join(' : ')}"
          @status = :fail
        end
      end

    rescue URI::InvalidURIError, OpenURI::HTTPError => e
      @status = :fail
      Scraper.logger.error("#{e} #{@uri}")
      if (self.url && @profile_id)then
        blacklisted = Blacklisted.find_or_create_by_hashed_name(:hashed_name => Digest::MD5.hexdigest(self.url),:profile_id => @profile_id)
        Scraper.logger.info "Adding to blacklist #{blacklisted.hashed_name}"
      end
    rescue Timeout::Error
      @status = :fail
      Scraper.logger.error("Trace: #{$!.backtrace.join("\n")}")
    ensure
      @status ||= :fail
    end

    private

    #Try to convert page in UTF8
    def iconv(charset)
      Scraper.logger.debug "Parsing charset for #{@uri.to_s}"
      charset ||= "iso-8859-1"
      #convert charset and delete non-valid char
      @content[:raw] = Iconv.conv("UTF-8//IGNORE",charset,@content[:raw])
      Scraper.logger.debug "Charset convert from #{charset} for #{@uri.to_s}"
      return true
    rescue Error => e
      Scraper.logger.error "Error in charset #{e} for #{@uri.to_s}"
      return false
    end


    def get_binding(params)
      binding
    end

    def get_scraper()
      path = File.split(scraper_filename)
      name = path[1]
      #per i terzi domini prova lo scraper del dominio principale
      tmp_name    = name.split("-")
      tmp_name[0] = "www"
      name_variations = [File.join(path[0],name), File.join(path[0],tmp_name.join("-"))]
      scraper = nil
      name_variations.each do |n|
        if File.exists?(n) then
          file  = IO.read(n)
          scraper = eval(file)
          break
        end
      end
      return scraper
    end

    def has_scraper?
      File.exists?(scraper_filename)
    end

    def scraper_filename
      filename = @uri.host.gsub(/\W/,"-").gsub(/\-{2,}/,"-").sub(/^\-+(.*)/,'\1').sub(/(.*)\-+$/,'\1')
      File.join(File.dirname(__FILE__), "scrapers", "pages", filename + ".rb")
    end

  end

end
