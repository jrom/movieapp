require 'yajl'

class User < Mingo
  property :username
  property :name
  
  def username=(value)
    self['username'] = self.class.generate_username(value)
  end
  
  def to_param
    username
  end
  
  def created_at
    @created_at ||= self.id && self.id.generation_time
  end
  
  def twitter_friends=(ids)
    self['twitter_friends'] = ids
  end
  
  def facebook_friends=(ids)
    self['facebook_friends'] = ids
  end
  
  def friends(query = {}, options = {})
    query = query.merge('$or' => [
      { 'twitter.id' => {'$in' => Array(self['twitter_friends'])} },
      { 'facebook.id' => {'$in' => Array(self['facebook_friends'])} }
    ])
    self.class.find(query, options)
  end
  
  def movies_from_friends
    users = friends({'watched' => {'$exists' => true}}, :fields => [:watched])
    movie_ids = friends.map { |u| u.watched.object_ids }.flatten.uniq
    Movie.find '_id' => {'$in' => movie_ids}
  end
  
  # 'to_watch' => [movie_id1, movie_id2, ...]
  many :to_watch, Movie
  
  # 'watched' => [{ 'movie' => movie_id1, 'liked' => true }, { ... }, ...]
  many :watched, Movie do
    # defines how to collect IDs of movies to load from the databae
    def object_ids
      @embedded.map { |watched| watched['movie'] }
    end
    
    # defines how to convert given object (or document) to a custom
    # construct to be embedded directly in parent document
    def convert(doc)
      if doc.is_a?(Hash) and not doc.is_a?(Mingo) then doc
      else
        raise ArgumentError, "got #{doc.inspect}" unless doc.is_a? Mingo or doc.is_a? BSON::ObjectId
        {'movie' => doc.id, 'time' => Time.now.utc}
      end
    end
    
    def include?(doc)
      @embedded.any? { |e| e['movie'] == doc.id }
    end
    
    # overload delete to find matching embedded value
    def delete(doc)
      doc = @embedded.find { |e| e['movie'] == doc.id }
      super(doc) if doc
    end
    
    # overload push operator to remove matching movie from `to_watch` list
    def <<(doc)
      super.tap do |result|
        @parent.to_watch.delete(doc.instance_of?(Hash) ? doc['movie'] : doc)
      end
    end
    
    # custom method that wraps `<<` to add a movie with rating
    def add_with_rating(movie, liked)
      liked = case liked.downcase
        when 'yes', 'true', '1' then true
        when 'no', 'false', '0' then false
        else nil
        end if liked.respond_to? :downcase

      self << convert(movie).update('liked' => liked)
    end
    
    def rating_for(movie)
      metadata = @embedded.find { |e| e['movie'] == movie.id }
      metadata['liked']
    end
    
    # defines an anonymous module that each movie in this collection
    # will be "decorated" (extended) with after being loaded
    decorate_with do
      attr_accessor :liked, :time_added
      def liked?() !!@liked end
    end
    
    # defines a block that will yield for each movie loaded from
    # the database, useful for decorating movies with extra information
    decorate_each do |movie, embedded|
      metadata = embedded.find { |e| e['movie'] == movie.id }
      movie.liked = metadata['liked']
      movie.time_added = metadata['time']
    end
    
    def liked
      liked_ids = @embedded.map { |watched| watched['movie'] if watched['liked'] }.compact
      @model.find({:_id => {'$in' => liked_ids}}, find_options)
    end
    
    def import_from_facebook(movies)
      existing_ids = object_ids
      facebook_ids = movies.each { |movie| movie['id'].to_i }
      from_facebook = @model.find(:facebook_id => {'$in' => facebook_ids}).index_by { |m| m['facebook_id'] }
      
      movies.each do |movie|
        unless found = from_facebook[movie['id'].to_i]
          searched = @model.search movie['name']
          unless searched.empty?
            found = searched.first.tap { |m|
              m['facebook_id'] = movie['id'].to_i
              m.save
            }
          end
        end
        
        if found and not existing_ids.include? found.id
          time = Time.parse movie['created_time']
          self << convert(found).update('liked' => true, 'time' => time)
        end
      end
    end
  end
  
  TwitterFields = %w[name location created_at url utc_offset time_zone id lang protected followers_count screen_name]
  
  def twitter_info=(info)
    self['twitter'] = info.to_hash.slice(*TwitterFields).tap do |data|
      self.username ||= data['screen_name']
      self.name ||= data['name']
    end
  end
  
  def self.from_twitter(twitter)
    login_from_twitter_or_facebook(twitter, nil)
  end
  
  def from_twitter?
    !!self['twitter']
  end
  
  def from_facebook?
    !!self['facebook']
  end
  
  def facebook_info=(info)
    self['facebook'] = info.to_hash.tap do |data|
      self.username ||= data['link'].scan(/\w+/).last
      self.name ||= data['name']
    end
  end
  
  def self.from_facebook(facebook)
    login_from_twitter_or_facebook(nil, facebook)
  end
  
  def self.find_from_twitter_or_facebook(twitter_info, facebook_info)
    if twitter_info or facebook_info
      first({}.tap { |conditions|
        conditions['twitter.id'] = twitter_info.id if twitter_info
        conditions['facebook.id'] = facebook_info.id if facebook_info
      })
    end
  end
  
  def self.login_from_twitter_or_facebook(twitter_info, facebook_info)
    raise ArgumentError unless twitter_info or facebook_info
    twitter_user = twitter_info && first('twitter.id' => twitter_info.id)
    facebook_user = facebook_info && first('facebook.id' => facebook_info.id)
    
    if twitter_user.nil? and facebook_user.nil?
      self.new
    elsif twitter_user == facebook_user or facebook_user.nil?
      twitter_user
    elsif twitter_user.nil?
      facebook_user
    else
      merge_accounts(twitter_user, facebook_user)
    end.
      tap do |user|
        user.twitter_info = twitter_info if twitter_info
        user.facebook_info = facebook_info if facebook_info
        user.save
      end
  end
  
  def self.merge_accounts(user1, user2)
    if user2.created_at < user1.created_at
      user2.merge_account(user1)
    else
      user1.merge_account(user2)
    end
  end
  
  def merge_account(other)
    other.each do |key, value|
      self[key] = value if value and self[key].nil?
    end
    other.destroy
    return self
  end
  
  def fetch_twitter_info(twitter_client)
    response = twitter_client.get('/1/friends/ids.json')
    friends_ids = Yajl::Parser.parse response.body
    self.twitter_friends = friends_ids
    save
  end
  
  def fetch_facebook_info(facebook_client)
    response_string = facebook_client.get('/me', :fields => 'movies,friends')
    user_info = Yajl::Parser.parse response_string
    self.facebook_friends = user_info['friends']['data'].map { |f| f['id'].to_i }
    watched.import_from_facebook user_info['movies']['data']
    save
  end
  
  def self.generate_username(name)
    name.dup.tap do |unique_name|
      unique_name.sub!(/\d*$/) { $&.to_i + 1 } while username_taken?(unique_name)
    end
  end
  
  Reserved = %w[following followers favorites timeline search home about login logout signup movies director]
  
  def self.username_taken?(name)
    Reserved.include?(name) or find(:username => name).has_next?
  end
  
  def self.get_id(obj)
    case obj
    when String then BSON::ObjectId(obj)
    when BSON::ObjectId then obj
    else obj.id
    end
  end
end
