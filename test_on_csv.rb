require 'rubygems'
require 'open-uri'
require 'lib/readability'
require 'timeout'

#------------------Data from CSV

USERAGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; it; rv:1.9.2.9) Gecko/20100824 Firefox/3.6.9"

FasterCSV.open("/home/andreafeltrin/Scrivania/file_geox.csv", "w") do |csv|
FasterCSV.open("/home/andreafeltrin/Scrivania/Geox_originale.csv", "r") do |row|
  row.each  { |row|
       begin

          url = row[0].to_s
           (doc = open(url, {'User-Agent' => USERAGENT}).read)
            #read = Readability::Document.new(doc).content
            found = Readability::Document.new(doc).date(url)
            lang  = Readability::Document.new(doc).lang(url)

            # url page, catname: name category, published: data on db,
            # found: data found on page, lang: page language
             csv << [url, found, lang]

       rescue OpenURI::HTTPError, NoMethodError, Timeout::Error, Exception => e
          #p url
          #p e
           csv << [url, "Error. Page not exist or page redirect"]
          timeout = e #save timeout error
        end

  }
  end
end