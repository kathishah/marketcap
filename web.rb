require 'sinatra'
require 'cgi'
require 'json'
require 'net/http'
require 'uri'

@@lookup = JSON.parse(IO.read("lookup.json"))
QUERY_URL = "http://query.yahooapis.com/v1/public/yql?q=sql%0A%09%09&format=json&env=" + CGI.escape("http://datatables.org/alltables.env")

get '/' do
  usage =	"Usage:<br/>" + "<table><tr><td>/lookup/</td></tr>" +
  "<tr><td>&nbsp;</td><td>exchange</td></tr>" +
  "<tr><td>&nbsp;</td><td>sector</td></tr>" +
  "<tr><td>&nbsp;</td><td>industry</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.sector</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.industry</td></tr>" +
  "<tr><td>&nbsp;</td><td>yahoo.finance.industry_by_sector?sub_key=sector_name</td></tr>" +
  "</table>"
  usage
end

get '/large_growing_cheap/:sector' do
  industries = @@lookup['yahoo.finance.industry_by_sector'][params[:sector]].keys.sort
  # load symbols
  symbols = []
  @@lookup['symbol_by_industry'].each { |ind|
    next unless industries.sort.index(ind["id"])
    ind['company'].each { |c| symbols << c['symbol'] }
  }
  logger.info("Found #{symbols.length} symbols")
  query = "select symbol from yahoo.finance.quotes where " +
    "MarketCapitalization > 5 and " + #5B
    "PERatio <= 20 and " +
    "PriceSales <= 1.3 and " #P/S
    #TODO Earnings growth estimate
  results = []
  if symbols.size > 100
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
        results << j_response['query']['results']['quote']
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
      results << j_response['query']['results']['quote']
    end
  end
  JSON.pretty_generate(results.flatten)
end

get '/lookup/:key' do
  if @@lookup.has_key?params[:key]
    if params[:sub_key]
      @@lookup[params[:key]][params[:sub_key]].to_json
    else
      @@lookup[params[:key]].to_json
    end
  else
    "Not found"
  end
end

get '/refresh/lookup' do
  @@lookup = JSON.parse(IO.read("lookup.json"))
end

