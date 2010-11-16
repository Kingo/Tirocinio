require 'iconv'
class String
  def to_italian_date(separator="/")
    tmp = self.split(separator)
    if tmp.size == 3 then
      Date.new(tmp[2].size == 2 ? ("20"+tmp[2]).to_i : tmp[2].to_i,tmp[1].to_i,tmp[0].to_i)
    end
  end
  # Piccolo hack per rendere più stabile lo scraping
  def inner_text
    return self
  end
    
  # Piccolo hack per rendere più stabile lo scraping
  def inner_html
    return self
  end


  # TODO: da testare
  # string.gsub Regexp.new('<!--.*?-->', Regexp::MULTILINE, 'u'), ''
  # string.gsub! Regexp.new('<(script|style).*?>.*?<\/(script|style).*?>',
  # Regexp::MULTILINE, 'u'), ''
  # string.gsub! Regexp.new('<.+?>',
  # Regexp::MULTILINE, 'u'), ''
  # string.gsub Regexp.new('\s+', Regexp::MULTILINE, 'u'), ' '

  def strip_all
    return self.strip_tags.strip_ct_nl.strip
  end
  #Remove html tag and html content
  def strip_tags
    return self.gsub( %r{</?[^>]+?>}, '' )
  end
  #remove Carriage return e New Line
  def strip_ct_nl
    self.gsub(%r{[\t\r\n]}, '')
  end

  def to_iso
    begin
      c = Iconv.new('ISO-8859-15//IGNORE','UTF-8')
      result = c.iconv(self)
    rescue
      result = self
    end
  end
end