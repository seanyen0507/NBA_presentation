require_relative 'spec_helper'
require_relative 'support/story_helpers'
require 'json'

describe 'Simple NBA Stories' do
  include StoryHelpers

  describe 'Getting the root of the service' do
    it 'Should return ok' do
      get '/'
      last_response.must_be :ok?
    end
  end

  describe 'Getting player information' do
    it 'should return their information' do
      get '/api/v1/player/kobe_bryant.json'
      last_response.must_be :ok?
    end

    # it 'should return 404 for unknown user' do
    #   get "/api/v1/player/#{random_str(20)}.json"
    #   last_response.must_be :not_found?
    # end
  end

  describe 'Checking users search' do
    before do
      Nbaplayer.delete_all
    end

    it 'should find none palyers' do
      header = { 'CONTENT_TYPE' => 'application/json' }
      body = {}

      post '/api/v1/nbaplayers', body, header
      last_response.must_be :bad_request?
    end

    it 'should return 404 for unknown players' do
      header = { 'CONTENT_TYPE' => 'application/json' }
      body = {
        desription: 'Check invalid playernames',
        playernames: [random_str(30), random_str(30)]
      }

      post '/api/v1/nbaplayers', body.to_json, header
      last_response.must_be :redirect?
      follow_redirect!
      # last_response.must_be :not_found?
    end

    it 'should return 400 for bad JSON formatting' do
      header = { 'CONTENT_TYPE' => 'application/json' }
      body = random_str(5)

      post '/api/v1/nbaplayers', body, header
      last_response.must_be :bad_request?
    end
  end
end