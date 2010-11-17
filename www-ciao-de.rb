doc       = Array.new
url_ciao_de       = 'http://www.ciao.de/'
host_ciao_de       = 'www.ciao.de'

keywords  = params[:keywords]

page    = agent.get(url_ciao_de)
form    = page.form('SearchForm1')
form.SearchString  = keywords
page    = agent.submit(form)

#pagina con la lista dei risultati, devo seguirli per recuperare i veri link

pages = page.search(".CWCiaoBingGridView .starRating a").map do |result|
  #URL generale
  url = result.get_attribute("href")
  if(url.include? '/Erfahrung') then
    uri         = URI.parse(url)
    uri.scheme  = 'http'
    uri.host    = host_ciao_de
    uri         = uri.to_s + '/SortOrder/2'
  end
end

pages.compact!
pages.uniq!

pages.each do |url|
  #open opinion page
  page_op = agent.get(url)
  page_op.search(".teaser small a").each do |opinion|
    link = opinion.get_attribute("onmousedown").gsub("', '","").gsub("this.href=jlinkBuild('","").gsub("/SortOrder/2');   return false;","")
    page_link = agent.get(link)
    author = page_link.at("#MemberProfileLink").inner_text.strip.decode_entities.gsub(/[\t\n\r]/, '')
    date = page_link.at(".opinionReviewDate").inner_text.strip.decode_entities.gsub(/[\t\n\r]/, '').gsub(".","")
    star = page_link.at(".opinionReviewDate span").get_attribute("content")
    doc << {:author => author, :published => date, :url => link, :evaluation => star}
  end
end
doc