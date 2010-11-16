begin
  require 'nokogiri'
rescue LoadError
  require 'rubygems'
  require 'nokogiri'
end
  
if defined?(Nokogiri)
  module Scraper
    module ContentExtractors

      # extracts title, content and links from html documents using the hpricot library
      class NokogiriContentExtractor < ContentExtractor

        def initialize(config)
          # if not configured, refuse to handle any content:
          if config.config then
            @pattern  = /^(text\/(html|xml)|application\/(xhtml\+xml|xml|atom\+xml))/
            @name     = config.config.name
            @config   = config.config
            @tags     = config.config.methods.delete_if { |x| !x.include?("tag_selector") || x.include?("tag_selector=")}.map {|x| x.sub("_tag_selector","")}
          end
         end

        # returns:
        # { :content => 'extracted clear text',
        #   :title => 'Title',
        #   :links => [array of urls] }
        def process(content)
          Scraper.logger.debug "-- #{@name} --"
          doc = Nokogiri::HTML(content)
          result = Hash.new
          @tags.each do |tag|      
            result[tag.to_sym] = self.send("extract_#{tag}",doc)
          end          
          return result
        end

        # Permette di implementare un metodo on the fly
        #in questo modo si ha la possibilità di aggiungere attributi
        #nella configurazione da fare lo scraping
        # es: extract_comments_title
        def method_missing(method_id,doc)
          Scraper.logger.debug "-- Calling method #{method_id}"
          m = method_id.id2name.split("_")
          if m[0] == "extract" then
            if m[1] then
              return extract(doc,"#{m[1]}_tag_selector".to_sym)
            end
          else
            raise "Method missing #{method_id}"
          end
        end


        def extract(doc,arg)
          Scraper.logger.debug "-- Extract #{arg}"
          result = tag_from_config(doc, arg) || doc.at('body')
          return result if result.nil?
          return result.to_s.strip_all
          #end
        end



        # Extracts textual content from the HTML tree.
        #
        # - First, the root element to use is determined using the
        # +content_element+ method, which itself uses the content_tag_selector
        # from RDig.configuration.
        # - Then, this element is processed by +extract_text+, which will give
        # all textual content contained in the root element and all it's
        # children.
        def extract_content(doc)
          content = ''
          ce = content_element(doc)
          ce = ce.inner_html if ce.respond_to? :inner_html
          content = strip_tags(strip_comments(ce)) if ce
          #          (ce/'h1, h2, h3, h4, h5, h6, p, li, dt, dd, td, address, option, ').each do |child|
          #          extract_text child, content
          return content.strip
        end

        # extracts the href attributes of all a tags, except
        # internal links like <a href="#top">
        def extract_links(doc)
          (doc/'a').map { |link|
            href = link['href']
            CGI.unescapeHTML(href) if href && href !~ /^#/
          }.compact
        end

        # Extracts the title from the given html tree
        def extract_title(doc)
          the_title_tag = title_tag(doc)
          return the_title_tag unless the_title_tag.respond_to? :inner_html
          strip_tags(the_title_tag.inner_html)
        end

        # Extracts the meta generator from the given html tree
        def extract_generator(doc)
          if (tmp = doc.at("meta[@name='generator']")) then
            return tmp.attributes['content'].downcase
          end
        end
        
        # Returns the element to extract the title from.
        #
        # This may return a string, e.g. an attribute value selected from a meta
        # tag, too.
        def title_tag(doc)
          tag_from_config(doc, :title_tag_selector) || doc.at('title')
        end

        # Retrieve the root element to extract document content from
        def content_element(doc)
          tag_from_config(doc, :content_tag_selector) || doc.at('body')
        end

        def tag_from_config(doc, config_key)
          cfg = @config.send(config_key)
          cfg.is_a?(String) ? doc.css(cfg) : cfg.call(doc) if cfg
        end

        # Return the given string minus all html comments
        def strip_comments(string)
          string.gsub Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), ''
        end
        def strip_tags(string)
          string.gsub! Regexp.new('<(script|style).*?>.*?<\/(script|style).*?>',
            Regexp::MULTILINE, 'u'), ''
          string.gsub! Regexp.new('<.+?>',
            Regexp::MULTILINE, 'u'), ''
          string.gsub Regexp.new('\s+', Regexp::MULTILINE, 'u'), ' '
        end

      end

    end
  end
end
