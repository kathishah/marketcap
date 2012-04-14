require 'sinatra'
require 'json'

@@lookup = JSON.parse(IO.read("lookup.json"))

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

