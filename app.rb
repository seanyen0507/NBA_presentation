require 'sinatra/base'
require_relative 'model/nbaplayer'
require 'NBA_info'
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

  API_BASE_URI = 'http://localhost:9292'
  helpers do
    def get_profile(playername)
      sam = Scraper.new
      profile_after = {
        'name' => playername, 'profiles' => []
      }
      begin
        begin
          name = params[:playername]
          sam.profile(name)[0].each do |key, value|
            profile_after['profiles'].push('Box-score' => key, 'Record' => value)
          end
        rescue
          nil
        else
          profile_after
        end
      rescue
        halt 404
      end
    end

    def check_start_lineup(playernames, des)
      @lineup = {}
      @body_null = true
      sean = Scraper.new
      # begin
      #   get_profile(playernames).nil ? @player_wrong = false : @player_wrong=\
      # true
      #   fail 'err' if @player_wrong == false
      # rescue
      #   halt 404
      # end
      begin
        playernames == '' ? @body_null = false : @body_null = true
        fail 'err' if @body_null == false
      rescue
        halt 400
      end
      begin
        po = sean.game[0]
        s = sean.game[2]
        po.each do |key, _value|
          if key.include? 'PM'
            5.times do
              temp = s.shift
              playernames.each do |playername|
                lastname = playername.split(' ').last
                if temp.include?(lastname.capitalize)
                  @lineup[playername] = 'Yes, he is in start lineup today.'
                end
              end
            end
          else
            3.times { s.shift }
          end
        end
        playernames.each do |playername|
          unless @lineup.key?(playername)
            @lineup[playername] = 'No, he is not in start lineup today.'
          end
        end
      rescue
        halt 404
      else
        @lineup
      end
    end

    def current_page?(path = ' ')
      path_info = request.path_info
      path_info += ' ' if path_info == '/'
      request_path = path_info.split '/'
      request_path[1] == path
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
    @nba = get_profile(:playername)
    @playername = params[:playername]

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
       flash[:notice] = 'usernames not found'
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

    flash[:notice] = 'record of tutorial updated'

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
    flash[:notice] = 'record of tutorial deleted'
    redirect '/nbaplayers'
  end

  get '/api/v1/player/:playername.json' do
    content_type :json
    get_profile(params[:playername]).to_json
  end

  post '/api/v1/nbaplayers' do
    content_type :json
    begin
      req = JSON.parse(request.body.read)
      logger.info req
    rescue
      halt 400
    end
    nbaplayer = Nbaplayer.new
    nbaplayer.description = req['description'].to_json
    nbaplayer.playernames = req['playernames'].to_json

    redirect "api/v1/nbaplayers/#{nbaplayer.id}" if nbaplayer.save
  end

  get '/api/v1/nbaplayers/:id' do
    content_type :json
    begin
      @nbaplayer = Nbaplayer.find(params[:id])
      description = JSON.parse(@nbaplayer.description)
      playernames = JSON.parse(@nbaplayer.playernames)
    rescue
      halt 400
    end
    check_start_lineup(playernames, description).to_json
  end

  put '/api/v1/nbaplayers/:id' do
    content_type :json
    begin
      req = JSON.parse(request.body.read)
      logger.info req
    rescue
      halt 400
    end
    nbaplayer = Nbaplayer.update(params[:id],req['playernames'].to_json)
  end

  delete '/api/v1/nbaplayers/:id' do
    nbaplayer = Nbaplayer.destroy(params[:id])
  end
end
