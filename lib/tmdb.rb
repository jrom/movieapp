require 'net/http'
require 'cgi'
require 'uri'
require 'yajl/json_gem'
require 'nibbler/json'
require 'active_support/all'
require 'logger'

module Tmdb
  # http://api.themoviedb.org/2.1/methods/Movie.search
  def self.search term
    uri = URI.parse("http://api.themoviedb.org/2.1/Movie.search/en/json/#{$settings.tmdb.api_key}/#{CGI.escape term}")
    json_string = Net::HTTP.get(uri)
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
    element 'posters' => :poster_cover, :with => lambda { |posters|
      poster = posters.find { |p| p["image"]["size"] == "cover" }
      poster.nil? ? '' : poster["image"]["url"]
    }
    element 'posters' => :poster_thumb, :with => lambda { |posters|
      poster = posters.find { |p| p["image"]["size"] == "thumb" }
      poster.nil? ? '' : poster["image"]["url"]
    }    
  end
  
  class Result < NibblerJSON
    elements :movies, :with => Movie
  end
  
end

if $0 == __FILE__
  require 'spec/autorun'
  
  describe Tmdb::Movie do
    
    RESULT = Tmdb.parse(DATA.read)
    
    subject { RESULT.movies.first }
    
    its(:id)                { should == 1075 }
    its(:name)              { should == 'Black Cat, White Cat' }
    its(:alternative_name)  { should == 'Black Cat, White Cat' }
    its(:original_name)     { should == 'Crna mačka, beli mačor' }
    its(:imdb_id)           { should == 'tt0118843' }
    its(:url)               { should == 'http://www.themoviedb.org/movie/1075' }
    its(:synopsis)          { should include('Matko is a small time hustler') }
    its(:year)              { should == 1998 }
    its(:poster_cover) {
      should == 'http://hwcdn.themoviedb.org/posters/64f/4bf41d18017a3c320a00064f/crna-macka-beli-macor-cover.jpg'
    }
    
  end
end

__END__
[
  {
    "rating": 6.6,
    "votes": 3,
    "movie_type": "movie",
    "alternative_name": "Black Cat, White Cat",
    "name": "Black Cat, White Cat",
    "original_name": "Crna mačka, beli mačor",
    "popularity": 3,
    "translated": true,
    "overview": "Matko is a small time hustler, living by the Danube with his 17 year old son Zare. After a failed business deal he owes money to the much more successful gangster Dadan. Dadan has a sister, Afrodita, that he desperately wants to see get married so they strike a deal: Zare is to marry her. ",
    "last_modified_at": "2010-07-19 23:15:42",
    "url": "http://www.themoviedb.org/movie/1075",
    "language": "en",
    "adult": false,
    "id": 1075,
    "version": 29,
    "posters": [
      {
        "image": {
          "size": "original",
          "url": "http://hwcdn.themoviedb.org/posters/64f/4bf41d18017a3c320a00064f/crna-macka-beli-macor-original.jpg",
          "id": "4bf41d18017a3c320a00064f",
          "type": "poster",
          "height": 932,
          "width": 666
        }
      },
      {
        "image": {
          "size": "mid",
          "url": "http://hwcdn.themoviedb.org/posters/64f/4bf41d18017a3c320a00064f/crna-macka-beli-macor-mid.jpg",
          "id": "4bf41d18017a3c320a00064f",
          "type": "poster",
          "height": 700,
          "width": 500
        }
      },
      {
        "image": {
          "size": "cover",
          "url": "http://hwcdn.themoviedb.org/posters/64f/4bf41d18017a3c320a00064f/crna-macka-beli-macor-cover.jpg",
          "id": "4bf41d18017a3c320a00064f",
          "type": "poster",
          "height": 259,
          "width": 185
        }
      },
      {
        "image": {
          "size": "thumb",
          "url": "http://hwcdn.themoviedb.org/posters/64f/4bf41d18017a3c320a00064f/crna-macka-beli-macor-thumb.jpg",
          "id": "4bf41d18017a3c320a00064f",
          "type": "poster",
          "height": 129,
          "width": 92
        }
      }
    ],
    "certification": "",
    "imdb_id": "tt0118843",
    "backdrops": [
      {
        "image": {
          "size": "original",
          "url": "http://hwcdn.themoviedb.org/backdrops/703/4bc90f20017a3c57fe005703/crna-macka-beli-macor-original.jpg",
          "id": "4bc90f20017a3c57fe005703",
          "type": "backdrop",
          "height": 720,
          "width": 1280
        }
      },
      {
        "image": {
          "size": "poster",
          "url": "http://hwcdn.themoviedb.org/backdrops/703/4bc90f20017a3c57fe005703/crna-macka-beli-macor-poster.jpg",
          "id": "4bc90f20017a3c57fe005703",
          "type": "backdrop",
          "height": 439,
          "width": 780
        }
      },
      {
        "image": {
          "size": "thumb",
          "url": "http://hwcdn.themoviedb.org/backdrops/703/4bc90f20017a3c57fe005703/crna-macka-beli-macor-thumb.jpg",
          "id": "4bc90f20017a3c57fe005703",
          "type": "backdrop",
          "height": 169,
          "width": 300
        }
      }
    ],
    "released": "1998-09-10",
    "score": 4.3219414
  }
]
