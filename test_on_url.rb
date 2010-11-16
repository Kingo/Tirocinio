require 'rubygems'
require 'open-uri'
require 'lib/readability'
require 'dbi'
require 'timeout'
require 'lib/date_parser'
require 'fastercsv'

#--------------------Data from DB (see below)
USERAGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; it; rv:1.9.2.9) Gecko/20100824 Firefox/3.6.9"

dbh = DBI.connect('DBI:Mysql:reputation_development', 'root','benvenuto-1')
#sth = dbh.prepare('select pages.url as url, published, categories.name as cat_name from pages  JOIN (sources, categories) ON (pages.source_id = sources.id AND sources.category_id = categories.id) where pages.status != 50 AND pages.profile_id = 1052296610 AND published > "2010-01-04" AND category_id = 2 LIMIT 30')
sth = dbh.prepare('select pages.url as url, published, categories.name as cat_name from pages  JOIN (sources, categories) ON (pages.source_id = sources.id AND sources.category_id = categories.id) where pages.url="http://www.agoravox.it/I-nutrizionisti-lanciano-l-allarme.html"')
sth.execute

FasterCSV.open("/home/andreafeltrin/Scrivania/file.csv", "w") do |csv|

  # Print out each row
  while row=sth.fetch do
    begin
      url = row[0].to_s
      doc = open(url).read
      #p Readability::Document.new(doc).content
a = Readability::Document.new(doc)
p "f"
p a.content
      cat_name =  row[2].to_s
      published = row[1].to_s
      found = Readability::Document.new(doc).date(url)
      lang  = Readability::Document.new(doc).lang(url)

      # url page, catname: name category, published: data on db,
      # found: data found on page, lang: page language
      ##csv << [url, cat_name, published, found, lang]


    rescue OpenURI::HTTPError => error
      #p error.io.status[0]
      csv << [url ,cat_name, published, "Error http type "+error.io.status[0]]
    rescue NoMethodError, Timeout::Error, Exception => e
      #p url
      #p e
      csv << [url ,cat_name, published,"Error. Page not exist or page redirect"]
      timeout = e #save timeout error
    end
  end
end

sth.finish
dbh.disconnect

