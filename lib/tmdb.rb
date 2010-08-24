require 'net/http'
require 'yajl/json_gem'
require 'nibbler/json'
require 'addressable/template'
require 'active_support/core_ext/object/blank'

module Tmdb
  
  # http://api.themoviedb.org/2.1/methods/Movie.search
  SEARCH_URL = Addressable::Template.new 'http://api.themoviedb.org/2.1/Movie.search/en/json/{api_key}/{query}'
  
  def self.search query
    url = SEARCH_URL.expand :api_key => Movies::Application.config.tmdb.api_key, :query => query
    json_string = Net::HTTP.get url
    parse json_string
  end
  
  def self.parse json_string
    Result.parse json_string
  end
  
  class Movie < NibblerJSON
    element :id, :with => lambda { |id| id.to_i }
    element :name
    element :alternative_name
    element :original_name
    element :imdb_id
    element :url
    element 'overview' => :synopsis
    element 'released' => :year, :with => lambda { |date|
      Date.parse(date).year unless date.blank?
    }
  end
  
  class Result < NibblerJSON
    elements :movies, :with => Movie
  end
  
end
