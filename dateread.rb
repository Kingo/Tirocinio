module Readability
  class DateRead

    def initialize(url, content_tree)
      @url = url
      @content_tree = content_tree
      date
    end

    DATE =
      {#25 Jen 2009
      :eng =>/((31(?!\ (Feb(ruary)?|Apr(il)?|June?|(Sep(?=\b|t)t?|Nov)(ember)?)))|((30|29)(?!\ Feb(ruary)?))|(29(?=\ Feb(ruary)(st|nd|th)??\ (((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00)))))|(0?[1-9])|1\d|2[0-8])\ (Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)\ ((1[6-9]|[2-9]\d)\d{2})/,
      #1st apr 2009
      :eng2 =>/([0-9]?[0-9])(st|th|nd)?(\s)?(Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)\ (((19|20)[0-9][0-9])|([0-9]*[0-9]))/i,
      #september, 8 2010
      :eng3 => /(Jan(uary)?|Feb(ruary)?|Ma(r(ch)?|y)|Apr(il)?|Ju((ly?)|(ne?))|Aug(ust)?|Oct(ober)?|(Sep(?=\b|t)t?|Nov|Dec)(ember)?)(,)?\s(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(st|th|nd)?(,)?((\s)((19|20)[0-9][0-9]))/i,
      #Standard Time
      :content1 => /((Jan|Feb|Ma(r(ch)?|y)|Apr|Ju((ly?)|(ne?))|Aug|Oct|(Sep(?=\b|t)t?|Nov|Dec))\s(0[1-9]|[12][0-9]|3[01])\s([012][0-9]:[0-5][0-9]:[0-5][0-9])\s(\+\d{4})\s((19|20)[0-9][0-9]))/i,
      #gennaio 12 2009
      :content2 => /(gen(naio)?|feb(braio)?|mar(zo)?|apr(ile)?|mag(gio)?|giu(gno)?|lug(lio)?|ago(sto)?|set(tembre)?|ott(obre)?|nov(embre)?|dic(embre)?)\s([0-9]?[0-9])(,)?\s((19|20)[0-9][0-9])/i,
      #1999/12/31
      :content3 => /((19|20)[0-9][0-9])(-|\/|\.)(0[1-9]|1[12])(-|\/|\.)(0[1-9]|(1|2)[0-9]|3[0-1])/,
      #16 gennaio 2004 with &nbsp;
      :content4 =>/([0-9]?[0-9])\s((Gennaio|Febbraio|Marzo|Aprile|Maggio|Giugno|Luglio|Agosto|Settembre|Ottobre|Novembre|Dicembre)(&nbsp;)?)(\s)?((19|20)[0-9][0-9])/i,
      #27 aprile 2009
      #:contentX =>/([0-9]?[0-9])\s+(gennaio|febbario|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)\s((19|20)[0-9][0-9])/i,
      #31/12/2009
      :content5 => /(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(-|\/|\.)(0[1-9]|1[012]|[0-9]?[0-9])(-|\/|\.)((19|20)[0-9][0-9])/,
      #24/05/09
      :content6 =>/(0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(-|\/|\.)(0[1-9]|1[012]|[0-9]?[0-9])(-|\/|\.)([019][0-9])/,
      #13 aprile, 2009 o 13 aprile 2009 o aprile 2009 o 13 aprile 09
      :content7 => /((0[1-9]|[12][0-9]|3[01]|[0123]?[0-9])(\s|-)?(gen(naio)?|feb(braio)?|mar(zo)?|apr(ile)?|mag(gio)?|giu(gno)?|lug(lio)?|ago(sto)?|set(tembre)?|ott(obre)?|nov(embre)?|dic(embre)?)(,|\s|-)?(\s)?(((19|20)[0-9][0-9])|([019][0-9]))(\.)?)/i
    }

    DATE_REGEX = [:eng, :eng2, :eng3, :content1, :content2, :content3, :content4, :content5, :content6, :content7]



    #tag where there are date, sort by importance
    LIST_TAG = ['small','strong','span','p','div','td']


    def date

      candidati = []
      string_data = " "
      weight = 0


      if(string_data == " ") then
        if((string_data=/((19|20)[0-9][0-9])(\/|-)([0-9]?[0-9])(\/|-)([0-9]?[0-9])/.match(@url)) ||
              string_data=/([0-9]?[0-9])(\/|-)([0-9]?[0-9])(\/|-)((19|20)[0-9][0-9])/.match(@url)) then

          weight = 5
          string_data = DateParser.new().parse(string_data.to_s)
          candidati <<  {:txt => string_data, :weight => weight}
        else

          LIST_TAG.each do |e|
            @content_tree.search(e).each do |element|

              DATE_REGEX.each { |item|

                if (m=DATE[item].match(element.to_s.strip)) then

                  case e
                  when LIST_TAG[0] #small
                    weight = 4

                  when LIST_TAG[1], LIST_TAG[4] #strong, div
                    weight = 3

                  when LIST_TAG[2], LIST_TAG[3], LIST_TAG[5] #span, p , td
                    weight = 2
                  end

                  #replace &nbsp; with empty string
                  if (item == :content4) then
                    m = m.to_s.gsub(/(&nbsp;|\\240)/, "")
                  end

                  if(item != :content1)then
                    #content1 is  standard mode
                    #transform date in standard format
                    std_date = DateParser.new().parse(m.to_s)
                    candidati <<  {:txt => std_date, :weight => weight}
                  else
                    #date is standard
                    candidati <<  {:txt => m.to_s, :weight => weight}
                  end

                  #delete duplicate date
                  candidati =  candidati.to_a.uniq
                end

              }

            end
          end
        end
      end
      #remove first date, becose is the date of the search
      cand_remove(candidati)


      #Default txt and weight
      if(weight == 0)
        candidati << {:txt => string_data, :weight => weight}
      end
      candidati.first[:txt].to_s

    end

    def cand_remove(candidati)

      t = Time.now
      #if the date found is equal to today date
      if (candidati.length > 1) then
        today = t.strftime("%a"+" "+"%b"+" "+"%d"+" ")

        if (today.include?(candidati.first[:txt].to_s))then
          candidati.shift
        end
      end

    end


  end
end
