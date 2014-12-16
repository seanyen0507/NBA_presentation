require 'sinatra/base'
require 'json'
require 'haml'
require 'sinatra/flash'

require 'httparty'

# Simple version of nba_scrapper
class NBACatcherApp < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  use Rack::MethodOverride

  configure :production, :development do
    enable :logging
  end

  API_BASE_URI = 'http://nba-dynamo.herokuapp.com'
  API_VER = '/api/v1/'

  helpers do
    def current_page?(path = ' ')
      path_info = request.path_info
      path_info += ' ' if path_info == '/'
      request_path = path_info.split '/'
      request_path[1] == path
    end
    def api_url(resource)
      URI.join(API_BASE_URI, API_VER, resource).to_s
    end

  end

  get '/' do
    haml :home
  end

  get '/nba' do
    @playername = params[:playername]
    if @playername
      redirect "/nba/#{@playername}"
      return nil
    end
    haml :NBA
  end

  get '/nba/:playername' do
    @playername = params[:playername]
    @nba = HTTParty.get api_url("player/#{@playername}.json")

    if @playername && @nba.nil?
      flash[:notice] = 'playernames not found' if @nba.nil?
      redirect '/nba'
    end
    haml :NBA
  end

  get '/nbaplayers' do
    @action = :create
    haml :boxscore
  end

  post '/nbaplayers' do
    request_url = "#{API_BASE_URI}/api/v1/nbaplayers"
    playernames = params[:playernames].split("\r\n")
    params_h = {
      playernames: playernames,
      description: ['hi']
    }

    options =  {
      body: params_h.to_json,
      headers: { 'Content-Type' => 'application/json' }
    }

    result = HTTParty.post(request_url, options)

     if (result.code != 200)
       flash[:notice] = 'playernames not found'
       redirect '/nbaplayers'
       return nil
     end

    id = result.request.last_uri.path.split('/').last
    session[:result] = result.to_json
    session[:playernames] = playernames
    session[:action] = :create
    redirect "/nbaplayers/#{id}"
  end

  put '/nbaplayers/:id' do
    request_url = "#{API_BASE_URI}/api/v1/nbaplayers/#{params[:id]}"
    playernames = params[:playernames].split("\r\n")
    params_h = {
      playernames: playernames
    }

    options =  {
      body: params_h.to_json,
      headers: { 'Content-Type' => 'application/json' }
    }
    result = HTTParty.put(request_url,options)

    flash[:notice] = 'record of players updated'

    id = result.request.last_uri.path.split('/').last
    session[:result] = result.to_json
    session[:playernames] = playernames
    redirect "/nbaplayers/#{id}"
  end

  get '/nbaplayers/:id' do
    if session[:action] == :create
      @results = JSON.parse(session[:result])
      @playernames = session[:playernames]
    else
      request_url = "#{API_BASE_URI}/api/v1/nbaplayers/#{params[:id]}"
      options = { headers: { 'Content-Type' => 'application/json' } }
      result = HTTParty.get(request_url, options)
      @results = result
    end

    @id = params[:id]
    @action = :update
    haml :boxscore
  end

  delete '/nbaplayers/:id' do
    request_url = "#{API_BASE_URI}/api/v1/nbaplayers/#{params[:id]}"
    result = HTTParty.delete(request_url)
    flash[:notice] = 'record of players deleted'
    redirect '/nbaplayers'
  end
end
