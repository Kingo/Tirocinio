  class Useragent
    
    USERAGENTS = [
      "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; WOW64; SLCC1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)",
      "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)",
      "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; InfoPath.2)",
      "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0; Trident/4.0; GTB6; SLCC1; .NET CLR 2.0.50727; Media Center PC 5.0; Zu",
      "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Win64; x64; Trident/4.0; .NET CLR 2.0.50727; SLCC2; .NET CLR 3.5.3072",
      "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)",
      "Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.9.2.10) Gecko/20100914 Firefox/3.6.10 ( .NET CLR 3.5.30729)",
      "Mozilla/5.0 (Windows; U; Windows NT 5.1; it-IT) AppleWebKit/533.4 (KHTML, like Gecko) Chrome/5.0.375.127 Safari/533.4",
      "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; it-IT) AppleWebKit/312.5.2 (KHTML, like Gecko) Safari/312.3.3'",
      "Mozilla/5.0 (Windows; U; Windows NT 5.1; it-IT; rv:1.9.2.10) Gecko/20100914 Firefox/3.6.10",
    ]
    
    def initialize
      rand_useragent || 0
    end

    def rand_useragent
      rand_agent =  rand(USERAGENTS.length)
      return USERAGENTS[rand_agent]
    end
  end
