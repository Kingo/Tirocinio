module Readability
  class LangRead

    def initialize(url, content_tree, content_raw)
      @url = url
      @content_tree = content_tree
      @content_raw = content_raw
      language
    end

    TLD={
      :it => /(it\/|it\.|sm\/)/,
      :uk => /(uk\/|uk\.)/,
      :de => /(de\/|de\.)/,
      :fr => /(fr\/|fr\.)/,
      :es => /(es\/|es\.)/,
      :edu => /(edu\/)/, #US Education
      :gov => /(gov\/)/, #US Governament
      :ro => /(ro\/)/, #Romania
    }

    TLDa = [:it, :uk, :de, :fr, :es, :edu, :gov, :ro]
    ATTR = %w{lang xml:lang}



    def language

      what_lang = nil
      doc_ele = @content_tree.at('*')
      #trova la lingua della pagina a partire dall'attributo lang presente nel tag html
      ATTR.each do |item|
        if (doc_ele[item].to_s != "") then
          what_lang = doc_ele[item].to_s
        end
      end
      if (what_lang == nil)then
        #find TLD and presumed language
        TLDa.each do |obj|
          if (g=TLD[obj].match(@url) )then
            what_lang = g.to_s
            what_lang = what_lang.gsub(/(\/)$/, "")
          end
        end

        #if TLD is .orq,.com,.net ecc try to determinate language from main content
        #delete html tag
        @content_raw.gsub!(/(<[^>]*>)|\n|\t/s) {""}
        what_lang = @content_raw.language.to_s.capitalize
      end
      what_lang

    end

  end
end