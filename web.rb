require 'sinatra'
require 'cgi'
require 'json'
require 'net/http'
require 'uri'

@@lookup = JSON.parse(IO.read("lookup.json"))
QUERY_URL = "http://query.yahooapis.com/v1/public/yql?q=sql%0A%09%09&format=json&env=" + CGI.escape("http://datatables.org/alltables.env")

helpers do
  # Returns ticker symbols per sector
  def get_symbols(sector)
    symbols = []
    unless  @@lookup['yahoo.finance.industry_by_sector'].has_key? sector
      return symbols
    end
    industries = @@lookup['yahoo.finance.industry_by_sector'][sector].keys.sort
    @@lookup['symbol_by_industry'].each { |ind|
      next unless industries.index(ind["id"]) #move on if this is not one we are interested in
      unless ind['company']
        logger.warn("No companies found for #{ind.inspect}")
        next
      end
      ind['company'].each { |c| symbols << c['symbol'] }
    }
    symbols
  end

  # Constructs query using the symbols. Uses filter_proc to filter the results on the way out.
  # Especially useful for filtering based on market cap because the data may look like 7.034B or
  # 11.213M
  def run_query(symbols, query, filter_proc=nil)
    results = []
    if symbols.size > 100
      # create batches so that the GET has less than 4096 chars
      batches = symbols.size / 100 + 1
      (1..batches).each { |batch_id|
        index_start = (batch_id - 1) * 100
        index_end   = (batch_id * 100) - 1
        index_end   = symbols.size - 1 if index_end > (symbols.size - 1)
        q = query + 'symbol in ("' + symbols[index_start..index_end].join('","') + '")'
        logger.info(q)
        url = QUERY_URL.gsub("sql", CGI.escape(q))
        logger.info(url)
        response = Net::HTTP.get_response(URI.parse(url))
        logger.info(response)
        if response.is_a?Net::HTTPOK
          j_response = JSON.parse(response.body)
          logger.info(j_response)
          if filter_proc
            results << j_response['query']['results']['quote'].select { |x| filter_proc.call(x) }
          else
            results << j_response['query']['results']['quote']
          end
        end
      }
    else
      query = query + 'symbol in ("' + symbols.join('","') + '")'
      logger.info(query)
      url = QUERY_URL.gsub("sql", CGI.escape(query))
      logger.info(url)
      response = Net::HTTP.get_response(URI.parse(url))
      logger.info(response.inspect)
      if response.is_a?Net::HTTPOK
        j_response = JSON.parse(response.body)
        logger.info(j_response)
        if j_response and j_response.has_key?'query' and j_response['query'].has_key?'results' and j_response['query']['results']
          if filter_proc
            results << j_response['query']['results']['quote'].select { |x| filter_proc.call(x) }
          else
            results << j_response['query']['results']['quote']
          end
        end
      end
    end
    results
  end
end

get '/' do
  usage =	"Usage:<br/>" + "<table><tr><td>/lookup/</td></tr>" +
  "<tr><td>&nbsp;</td><td>exchange</td></tr>" +
  "<tr><td>&nbsp;</td><td>sector</td></tr>" +
  "<tr><td>&nbsp;</td><td>industry</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.sector</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.industry</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.industry_by_sector/&lt;sector_name&gt;</td></tr>" +
  "</table>"
  usage
end

get '/preset/:preset_name/:sector' do
  symbols = get_symbols(params[:sector])
  if symbols.length == 0
    halt 404, 'Unknown sector. See: /lookup/yahoo.finance.sector'
  end
  logger.info("Found #{symbols.length} symbols")
  # create query
  query, special_condition = case
          when params[:preset_name] == "large_growing_cheap"
            ["select symbol,LastTradePriceOnly,Volume,MarketCapitalization from yahoo.finance.quotes where " +
            "PERatio <= 20 and " +
            "PriceSales <= 1.3 and ", #P/S
            Proc.new { |x|
              if x["MarketCapitalization"]
                mc = if x["MarketCapitalization"].end_with?'B'; x["MarketCapitalization"].gsub('B', '').to_i*(10**9); else; x["MarketCapitalization"].gsub('M','').to_i*(10**6); end
              else
                mc = 0
              end
              mc >= 5*(10**9) #5B
            }]
            #TODO Earnings growth estimate
#          when params[:preset_name] == "strong_forecasted_growth"
#            "select symbol,LastTradePriceOnly,Volume from yahoo.finance.quotes where " +
#            "MarketCapitalization >= 5 and " + #5B
#
          end
  results = run_query(symbols, query, special_condition)
  JSON.pretty_generate(results.flatten)
end

get '/preset/strong_forecasted_growth' do
end

get '/lookup/:key/?:sub_key?' do
  if @@lookup.has_key?params[:key]
    if params[:sub_key] 
      if @@lookup[params[:key]].has_key?params[:sub_key]
        @@lookup[params[:key]][params[:sub_key]].to_json
      else
        halt 404, "Sector not found. See /lookup/yahoo.finance.sector"
      end
    else
      @@lookup[params[:key]].to_json
    end
  else
    halt 404, "Lookup key not found. See usage at /"
  end
end

get '/refresh/lookup' do
  @@lookup = JSON.parse(IO.read("lookup.json"))
end

