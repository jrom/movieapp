module UsersHelper
  def username_with_icon(user)
    [].tap { |out|
      out << twitter_icon if user.from_twitter?
      out << facebook_icon if user.from_facebook?
      out << link_to_user(user)
    }.join(' ').html_safe
  end
  
  def user_name(user)
    user.name.presence || user.username
  end
  
  def link_to_user(user)
    link_to(user.username, watched_path(user), :title => user.name)
  end
  
  def my_page?
    logged_in? and current_user == @user
  end
  
  def my_watchlist?
    controller.action_name == 'to_watch' and my_page?
  end
  
  def watched_liked(movie, user = nil)
    who = user ? user.name : 'You'
    liked = user ? movie.liked? : current_user.watched.rating_for(movie)
    
    "#{who} watched this movie".tap do |out|
      unless liked.nil?
        if liked
          out << %( and <em class="liked">#{nobr 'liked it'}</em>)
        else
          out << %(, but <em class="disliked">#{nobr "didn't like it"}</em>)
        end
      end
      out << '.'
    end.html_safe
  end
  
  def from_where(user)
    if twitter_user? and facebook_user?
      'from Twitter and Facebook'
    elsif twitter_user?
      'from Twitter'
    elsif facebook_user?
      'from Facebook'
    end
  end
  
  def list_of_people(users, options = {})
    limit = options[:limit] || 3
    listed = users[0, limit].map { |user| link_to_user(user) }
    rest = users.size - limit
    listed << pluralize(rest, options[:other] || 'other') if rest > 0
    listed.to_sentence.html_safe
  end
end
