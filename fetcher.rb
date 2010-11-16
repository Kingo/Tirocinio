module Scraper 
  class Fetcher
    class << self
      def run(args)
        result = Array.new()
        args.each do |document|
          begin
            result << document if(document && document.fetch == :success)
          rescue Exception => e
            @logger.debug "Fetch error: #{e.inspect}"
          end    
        end
        return result.compact
      end
  
    end
  end
end