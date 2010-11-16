class DateParser
  def initialize(default = nil)
    @default = default || Time.now
  end
    
  def parse(date_published)
    # controlla che non sia già un datetime
    if (date_published.respond_to?(:date_time) || date_published.class == Time) then
      result = date_published 
    else
      result  = mktime_from_text(date_published)
    end
    #controlla che la data non sia null
    #o che non sia maggiore della data di reperimento 
      if result.nil? || result > @default then
          result = @default
      end
    rescue Exception => e
     result = @default
    ensure
      return result      
  end
  
  
  private
  
    def month_s_to_i(month)
      months = [/(gen|jan)/, /(feb|feb)/, /(mar|mar)/, /(apr|apr)/, /(mag|may)/, /(giu|jun)/, /(lug|jul)/, /(ago|aug)/, /(set|sep)/, /(ott|oct)/, /(nov|nov)/, /(dic|dec)/]
      if (month =~ /\d/) then
        #numerico?
        month = month.to_i
      else  
        #fai la corrispondenza da mese letterale a numerico
        months.each_index do |j|
          if month.downcase.match(months[j])
            month = j+1
            break
          end
        end
      end
      return month
    end
  
    def mktime_from_text(text)
      return nil if text.nil?
      text = text.downcase

      r = [
           {:regexp => /(\d{4})[\D]+(\d{1,2})[\D]+(\d{1,2})/ , :year => 1, :month => 2, :day => 3},  #2001/01/01
           {:regexp => /(\d{4})[\W]+(\w+)[\W]+(\d{1,2})/  , :year => 1, :month => 2, :day => 3},  #2001/01/01
           {:regexp => /(\d{1,2})[\D]+(\d{1,2})[\D]+(\d{4})/ , :year => 3, :month => 2, :day => 1}, #01/01/2001 01-01-2001 01 01 2001
           {:regexp => /(\d{1,2})[\D]+(\d{1,2})[\D]+(\d{2})/ , :year => 3, :month => 2, :day => 1}, #01/01/2001 01-01-2001 01 01 2001
           {:regexp => /(\d{1,2})[\W]+(\w+)[\W]+(\d{2,4})/, :year => 3, :month => 2, :day => 1}, #01/gen/2001 01 gen 2001 01 gennaio 01
           {:regexp => /(\d{1,2})[\D]+(\d{1,2})[\D]+(\d{2})/ , :year => 3, :month => 2, :day => 1} #01/01/01 formato molto generico
          ]
      

      year_range = (Time.now.year-10..Time.now.year)
      day_range  = (1..31)
      month_range= (1..12)
      result = nil
      r.each do |reg|   
        dates   = {:year => 0, :month => 0, :day => 0}
        if ((match = text.match(reg[:regexp])) && result.nil?) then 
          dates = {:year => match[reg[:year]].to_i, 
                  :month => month_s_to_i(match[reg[:month]]), 
                  :day => match[reg[:day]].to_i}
          begin  
            return Time.mktime(dates[:year], dates[:month], dates[:day])
          rescue ArgumentError => e
            result = nil
          end
        end 
      end
      return result   
    end
end