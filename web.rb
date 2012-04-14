require 'sinatra'
require 'json'

@@lookup = JSON.parse(IO.read("lookup.json"))

get '/' do
	"Hello dash"
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

