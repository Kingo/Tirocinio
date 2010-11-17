doc       = Array.new
keywords  = URI.escape(params[:keywords].gsub(" ","+"))
url = "http://video.google.it/videosearch?q="+keywords+"&hl=it&lr=lang_it&output=rss"
pages     = 1

xml = open(url) do |f|
  result = Nokogiri::XML(f)
  result.search("//item").each do |item|
    doc << {:url      => item.xpath("link").inner_text,
      :title          => item.xpath("media:group/media:title").inner_text,
      :content        => item.xpath("media:group/media:description").inner_text,
      :published      => Date.parse(item.xpath("pubDate").inner_text).strftime("%d-%m-%Y")
    }
  end
end

doc