require 'rubygems'
require 'nokogiri'
Dir["#{File.expand_path(File.dirname(__FILE__))}/../../../extend_string.rb"].each do |f|
  begin
    require f
  rescue LoadError
    Scraper.logger.error "could not load #{f}: #{$!}"
  end
end


if defined?(Nokogiri)
  module Scraper
    module ContentExtractors
      class Readability < ContentExtractor
        REGEXES = {
          :unlikelyCandidatesRe => /combx|comment|disqus|foot|header|menu|meta|nav|rss|shoutbox|sidebar|sponsor|like|fb|update|newprefooter|cright|upcheck|footer/i,
          :okMaybeItsACandidateRe => /testo_articolo_dimensione|and|article|body|column|main|articolo|testoNotizia|fAbs|data|datetime/i,
          :positiveRe => /articolo|testo_articolo_dimensione|contenuto|article|body|content|entry|hentry|page|pagination|post|text|data|datetime/i,
          :negativeRe => /combx|comment|contact|foot|footer|footnote|link|media|meta|promo|related|scroll|shoutbox|sponsor|tags|widget|upcheck/i,
          :divToPElementsRe => /<(a|blockquote|dl|img|div|ol|p|pre|table|ul)/i,
          :replaceBrsRe => /(<br[^>]*>[ \n\r\t]*){2,}/i,
          :replaceFontsRe => /<(\/?)font[^>]*>/i,
          :trimRe => /^\s+|\s+$/,
          :normalizeRe => /\s{2,}/,
          :killBreaksRe => /(<br\s*\/?>(\s|&nbsp;?)*){1,}/,
          :videoRe => /http:\/\/(www\.)?(youtube|vimeo)\.com/i
        }
        DATE =
          {#25 Jen 2009
          :eng =>/((31(?!\ (Feb(ruary)?|Apr(il)?|June?|(Sep(?=\b|t)t?|Nov)(ember)?)))|((30|29)(?!\ Feb(ruary)?))|(29(?=\ Feb(ruary)(st|nd|th)??\ (((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00)))))|(0?[1-9])|1\d|2[0-8])\ (Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)\ ((1[6-9]|[2-9]\d)\d{2})/,
          #1st apr 2009
          :eng2 =>/([0-9]?[0-9])(st|th|nd|rd)?(\s)?(Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)\ (((19|20)[0-9][0-9])|([0-9]*[0-9]))/i,
          #september, 8 2010
          :eng3 => /(Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)(\.)?(,)?\s(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(st|th|nd|rd)?(,)?((\s)((19|20)[0-9][0-9]))/i,

          #Standard Time
          :content1 => /((Jan|Feb|Ma(r(ch)?|y)|Apr|Ju((ly?)|(ne?))|Aug|Oct|(Sep(?=\b|t)t?|Nov|Dec))\s(0[1-9]|[12][0-9]|3[01])\s([012][0-9]:[0-5][0-9]:[0-5][0-9])\s(\+\d{4})\s((19|20)[0-9][0-9]))/i,
          #gennaio 12 2009
          :content2 => /(gen(naio)?|feb(braio)?|mar(zo)?|apr(ile)?|mag(gio)?|giu(gno)?|lug(lio)?|ago(sto)?|set(tembre)?|ott(obre)?|nov(embre)?|dic(embre)?)(,)?\s([0-9]?[0-9])(st|th|nd|rd)?(,)?\s((19|20)[0-9][0-9])/i,
          #16 gennaio 2004 with &nbsp;
          :content3 =>/([0-9]?[0-9])\s((gen(naio)?|feb(braio)?|mar(zo)?|apr(ile)?|mag(gio)?|giu(gno)?|lug(lio)?|ago(sto)?|set(tembre)?|ott(obre)?|nov(embre)?|dic(embre)?)(&nbsp;)?)(\s)?((19|20)[0-9][0-9])/i,

          #31/12/2009
          :content4 => /(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\/)(0[1-9]|1[012]|[0-9]?[0-9])(\/)((19|20)[0-9][0-9])/,
          #31-12-2009
          :content4a => /(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(-)(0[1-9]|1[012]|[0-9]?[0-9])(-)((19|20)[0-9][0-9])/,
          #31.12.2009
          :content4b => /(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\.)(0[1-9]|1[012]|[0-9]?[0-9])(\.)((19|20)[0-9][0-9])/,

          #24.05.09
          :content5 =>/(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\.)(0[1-9]|1[012]|[0-9]?[0-9])(\.)([019][0-9])/,
          #24-05-09
          :content5a =>/(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(-)(0[1-9]|1[012]|[0-9]?[0-9])(-)([019][0-9])/,
          #24/05/09
          :content5b =>/(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\/)(0[1-9]|1[012]|[0-9]?[0-9])(\/)([019][0-9])/,

          #13 aprile, 2009 o 13 aprile 2009 o aprile 2009 o 13 aprile 09
          :content6 => /((0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\s|-)?(gen(naio)?|feb(braio)?|mar(zo)?|apr(ile)?|mag(gio)?|giu(gno)?|lug(lio)?|ago(sto)?|set(tembre)?|ott(obre)?|nov(embre)?|dic(embre)?)(,|\s|-)?(\s)?(((19|20)[0-9][0-9])|([019][0-9]))(\.)?)/i,

          #2010-08-31
          :content7 => /((19|20)[0-9][0-9])(-)(0[1-9]|1[012])(-)(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])/i,
          #2010/08/31
          :content7a => /((19|20)[0-9][0-9])(\/)(0[1-9]|1[012])(\/)(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])/i,
          #2010.08.31
          :content7b => /((19|20)[0-9][0-9])(\.)(0[1-9]|1[012])(\.)(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])/i,
          #27 aprile
          #:contentX =>/([0-9]?[0-9])\s+(gennaio|febbario|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)/i,

        }

        DATE_REGEX = [:eng, :eng2, :eng3, 
                      :content1, :content2, :content3,
                      :content4, :content4a, :content4b,
                      :content5, :content5a, :content5b, :content6,
                      :content7, :content7a, :content7b
                      ]
                      
        TLD={
          :it => /(it|sm)/,
          :uk => /(uk)/,
          :de => /(de)/,
          :fr => /(fr)/,
          :es => /(es)/,
          :edu => /(edu)/, #US Education
          :gov => /(gov)/, #US Governament
          :ro => /(ro)/, #Romania
        }

        TLDa = [:it, :uk, :de, :fr, :es, :edu, :gov, :ro]

        ATTR = %w{lang xml:lang}
        #tag where there are date, sort by importance
        LIST_TAG = ['small','strong','span','p','div','td','meta']

        attr_accessor :options, :html

        def initialize(config={})
          @pattern = /^(text\/(html|xml)|application\/(xhtml\+xml|xml|atom\+xml))/ if config.config
          @url = config.config.url || ''
          #extractor name
          @name = config.config.name
          @text_lenght_threeshold = config.config.text_lenght_threeshold || 25
          @retry_lenght = config.config.retry_lenght || 250
        end

        def process(content)
          @input = content
          @options = {}
          make_html

          result = {
            :content => extract_content,
            :title => extract_title,
            :published => date,
            :lang => language
          }
          if (extract_content.length > 25)then
            return result
          else
            return nil
          end
        end

        def make_html
          @html = Nokogiri::HTML(@input, nil, 'UTF-8')
        end

        def extract_title
          result = @html.at('title').to_s
          result.gsub(/(<[^>]*>)|\n|\t/s) {""}
        end

        def extract_content(remove_unlikely_candidates = true)
          @html.css("script, style, like").each { |i| i.remove }

          remove_unlikely_candidates! if remove_unlikely_candidates
          transform_misused_divs_into_paragraphs!
          candidates = score_paragraphs(@text_lenght_threeshold)
          best_candidate = select_best_candidate(candidates)
          article = get_article(candidates, best_candidate)
          cleaned_article = sanitize(article, candidates, options)
          if remove_unlikely_candidates && article.text.strip.length < @retry_lenght
            make_html
            extract_content(false)
          else
            cleaned_article
          end
        end

        def get_article(candidates, best_candidate)
          # Now that we have the top candidate, look through its siblings for content that might also be related.
          # Things like preambles, content split by ads that we removed, etc.

          sibling_score_threshold = [10, best_candidate[:content_score] * 0.2].max
          output = Nokogiri::XML::Node.new('div', @html)


          best_candidate[:elem].parent.children.each do |sibling|
            append = false
            append = true if sibling == best_candidate[:elem]
            append = true if candidates[sibling] && candidates[sibling][:content_score] >= sibling_score_threshold

            if sibling.name.downcase == "p"
              link_density = get_link_density(sibling)
              node_content = sibling.text
              node_length = node_content.length

              if node_length > 80 && link_density < 0.25
                append = true
              elsif node_length < 80 && link_density == 0 && node_content =~ /\.( |$)/
                append = true
              end
            end

            if append
              sibling.name = "div" unless %w[div p].include?(sibling.name.downcase)
              output << sibling
            end
          end

          output
        end

        def select_best_candidate(candidates)
          sorted_candidates = candidates.values.sort { |a, b| b[:content_score] <=> a[:content_score] }

          debug("Top 5 canidates:")
          sorted_candidates[0...5].each do |candidate|
            debug("Candidate #{candidate[:elem].name}##{candidate[:elem][:id]}.#{candidate[:elem][:class]} with score #{candidate[:content_score]}")
          end

          best_candidate = sorted_candidates.first || { :elem => @html.css("body").first, :content_score => 0 }
          debug("Best candidate #{best_candidate[:elem].name}##{best_candidate[:elem][:id]}.#{best_candidate[:elem][:class]} with score #{best_candidate[:content_score]}")

          best_candidate
        end

        def get_link_density(elem)
          link_length = elem.css("a").map {|i| i.text}.join("").length
          text_length = elem.text.length
          link_length / text_length.to_f
        end

        def score_paragraphs(min_text_length)
          candidates = {}
          @html.css("p,td").each do |elem|
            parent_node = elem.parent
            grand_parent_node = parent_node.respond_to?(:parent) ? parent_node.parent : nil
            inner_text = elem.text

            # If this paragraph is less than 25 characters, don't even count it.
            next if inner_text.length < min_text_length

            candidates[parent_node] ||= score_node(parent_node)
            candidates[grand_parent_node] ||= score_node(grand_parent_node) if grand_parent_node

            content_score = 1
            content_score += inner_text.split(',').length
            content_score += [(inner_text.length / 100).to_i, 3].min

            candidates[parent_node][:content_score] += content_score
            candidates[grand_parent_node][:content_score] += content_score / 2.0 if grand_parent_node
          end

          # Scale the final candidates score based on link density. Good content should have a
          # relatively small link density (5% or less) and be mostly unaffected by this operation.
          candidates.each do |elem, candidate|
            candidate[:content_score] = candidate[:content_score] * (1 - get_link_density(elem))
          end

          candidates
        end

        def class_weight(e)
          weight = 0
          if e[:class] && e[:class] != ""
            if e[:class] =~ REGEXES[:negativeRe]
              weight -= 25
            end

            if e[:class] =~ REGEXES[:positiveRe]
              weight += 25
            end
          end

          if e[:id] && e[:id] != ""
            if e[:id] =~ REGEXES[:negativeRe]
              weight -= 25
            end

            if e[:id] =~ REGEXES[:positiveRe]
              weight += 25
            end
          end

          weight
        end

        def score_node(elem)
          content_score = class_weight(elem)
          case elem.name.downcase
          when "div":
              content_score += 5
          when "blockquote":
              content_score += 3
          when "form":
              content_score -= 3
          when "th":
              content_score -= 5
          end
          { :content_score => content_score, :elem => elem }
        end

        def debug(str)
          puts str if options[:debug]
        end

        def remove_unlikely_candidates!
          @html.css("*").each do |elem|
            str = "#{elem[:class]}#{elem[:id]}"
            if str =~ REGEXES[:unlikelyCandidatesRe] && str !~ REGEXES[:okMaybeItsACandidateRe] && elem.name.downcase != 'body'
              debug("Removing unlikely candidate - #{str}")
              elem.remove
            end
          end
        end

        def transform_misused_divs_into_paragraphs!


          @html.css("*").each do |elem|
            if elem.name.downcase == "div"
              # transform <div>s that do not contain other block elements into <p>s

              if elem.inner_html !~ REGEXES[:divToPElementsRe]
                debug ("Altering div(##{elem[:id]}.#{elem[:class]}) to p");
                elem.name = "p"
              end
            else
              # wrap text nodes in p tags
              # elem.children.each do |child|
              # if child.text?
              ## debug("wrapping text node with a p")
              # child.swap("<p>#{child.text}</p>")
              # end
              # end
            end
          end
        end

        def sanitize(node, candidates, options = {})

          node.css("h1, h2, h3, h4, h5, h6").each do |header|
            header.remove if class_weight(header) < 0 || get_link_density(header) > 0.33
          end

          node.css("form, object, iframe, embed").each do |elem|
            elem.remove
          end
          # remove empty <p> tags
          node.css("p").each do |elem|
            elem.remove if elem.content.strip.empty?
          end

          # Conditionally clean <table>s, <ul>s, and <div>s
          node.css("table, ul, div").each do |el|
            weight = class_weight(el)
            content_score = candidates[el] ? candidates[el][:content_score] : 0
            name = el.name.downcase

            if weight + content_score < 0
              el.remove
              debug("Conditionally cleaned #{name}##{el[:id]}.#{el[:class]} with weight #{weight} and content score #{content_score} because score + content score was less than zero.")
            elsif el.text.count(",") < 10
              counts = %w[p img li a embed input].inject({}) { |m, kind| m[kind] = el.css(kind).length; m }
              counts["li"] -= 100

              content_length = el.text.strip.length # Count the text length excluding any surrounding whitespace
              link_density = get_link_density(el)
              to_remove = false
              reason = ""
              if counts["img"] > counts["p"]
                reason = "too many images"
                to_remove = true
              elsif counts["li"] > counts["p"] && name != "ul" && name != "ol"
                reason = "more <li>s than <p>s"
                to_remove = true
              elsif counts["input"] > (counts["p"] / 3).to_i
                reason = "less than 3x <p>s than <input>s"
                to_remove = true
              elsif content_length < (@text_lenght_threeshold) && (counts["img"] == 0 || counts["img"] > 2)
                reason = "too short a content length without a single image"
                to_remove = true
              elsif weight < 25 && link_density > 0.2
                reason = "too many links for its weight (#{weight})"
                to_remove = true
              elsif weight >= 25 && link_density > 0.5
                reason = "too many links for its weight (#{weight})"
                to_remove = true
              elsif (counts["embed"] == 1 && content_length < 75) || counts["embed"] > 1
                reason = "<embed>s with too short a content length, or too many <embed>s"
                to_remove = true
              end

              if to_remove

                debug("Conditionally cleaned #{name}##{el[:id]}.#{el[:class]} with weight #{weight} and content score #{content_score} because it has #{reason}.")
                el.remove
              end
            end
          end

          # We'll sanitize all elements using a whitelist
          base_whitelist =%w[div p]

          # Use a hash for speed (don't want to make a million calls to include?)
          whitelist = Hash.new
          base_whitelist.each {|tag| whitelist[tag] = true }
          ([node] + node.css("*")).each do |el|
            # If element is in whitelist, delete all its attributes
            if whitelist[el.node_name]


              el.attributes.each { |a, x| el.delete(a)}

              # Otherwise, replace the element with its contents
            else
              #el.swap(el.text.gsub(%r{</?[^>]+?>}, ''))
              el.text.strip_tags
            end
          end
          # Get rid of duplicate whitespace
          node.to_html.gsub(/[\r\n\f]+/, "" ).gsub(/[\t ]+/, " ").gsub(/&nbsp;/, " ").strip_tags
        end



        def date
          make_html
          candidati = []
          string_data = " "
          weight = 0


          #if(string_data == " ") then
            if((string_data=/((19|20)[0-9][0-9])(\/|-)([0-9]?[0-9])(\/|-)([0-9]?[0-9])/.match(@url)) ||
                  string_data=/([0-9]?[0-9])(\/|-)([0-9]?[0-9])(\/|-)((19|20)[0-9][0-9])/.match(@url)) then

              weight = 5
              string_data = DateParser.new().parse(string_data.to_s)
              candidati <<  {:txt => string_data, :weight => weight}
            else

              LIST_TAG.each do |e|
                @html.search(e).each do |element|

                  DATE_REGEX.each { |item|

                    if (m=DATE[item].match(element.to_s.strip)) then

                      case e
                      when LIST_TAG[0], LIST_TAG[6] #small, meta
                        weight = 4

                      when LIST_TAG[1], LIST_TAG[4] #strong, div
                        weight = 3

                      when LIST_TAG[2], LIST_TAG[3], LIST_TAG[5] #span, p , td
                        weight = 2
                      end
                      #replace &nbsp; with empty string
                      if (item == :content3) then
                        m = m.to_s.gsub(/(&nbsp;|\\240)/, "")
                      end

                        #transform date in standard format
                        std_date = DateParser.new().parse(m.to_s)
                        candidati <<  {:txt => std_date.to_s, :weight => weight}

                      #delete duplicate date
                      candidati =  candidati.to_a.uniq
                    end
                  }

                end
              end
            end
         # end
          #remove first date, becose is the date of the search
          cand_remove(candidati)
          #Default txt and weight
          if(weight == 0)
            candidati << {:txt => "Day, Month, Hour", :weight => weight}
          end
          Scraper.logger.debug "ReadAbility Date #{candidati.first[:txt].to_s}"
          candidati.first[:txt]

        end

        def cand_remove(candidati)
          #if the date found is equal to today date
          if (candidati.length > 1) then
            # Becose W3C relese RDF => http://www.w3.org/TR/1999/REC-rdf-syntax-19990222/#basic
            if (candidati.first[:txt].to_s == "Lun, 22 Feb 1999 00:00:00 +0100")then
              candidati.shift
            end
            
            t = Time.now
            today = t.strftime("%a"+", "+"%d"+" "+"%b")
            while((today == (candidati.first[:txt].to_s.slice(0..10))) and (candidati.size > 1))
              candidati.shift
            end
          end

        end

        def language
          make_html
          what_lang = nil
          doc_ele = @html.at('*')
          #trova la lingua della pagina a partire dall'attributo lang presente nel tag html
          ATTR.each do |item|
            if (doc_ele[item].to_s != "") then
              what_lang = doc_ele[item].to_s
            end
          end
          return what_lang unless what_lang.nil?

          #find TLD and presumed language

          tld = URI::parse(@url).host.split('.').last
          what_lang = TLD.select do |k,v|
            tld =~ v
          end
          what_lang = what_lang.first.first if what_lang && what_lang.first
          return what_lang unless what_lang.nil?


          #if TLD is .orq,.com,.net ecc try to determinate language from main content
          #delete html tag
          text =  @html.inner_text.gsub(/[\r\n]/,' ').gsub(/\s{2,}/,' ')
          what_lang = text.language.to_s.capitalize
          what_lang

        end
      end
    end
  end
end