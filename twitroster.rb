require 'sinatra'
require 'json'
require 'httparty'
require 'uri'

configure :production, :development do
  CACHE_DIR = File.expand_path(File.dirname(__FILE__) + '/cache')
  TWITTER_CACHE_EXPIRY = (60*60) # in seconds
end

configure :development do
  HOST = "localhost:4567"
end

configure :production do
  HOST = "twitroster.com"
end

get '/' do
  @users = [User.new] * 5
  erb :index
end

post '/embed' do
  @users = params[:user].reject{|e| !e || e == ""}.collect{|e| User.new(e)}
  if @users.collect{|u| u.valid?}.all?
    @embed = @users.collect{|e| e.as_param}.join("&")
    erb :embed
  else
    erb :index
  end
end

get '/js' do
  content_type 'text/javascript'

  @users = params[:u].collect{|e| User.new(e)}
  @users.each{|e| e.load}
  
  @sanitize = (params[:s] == "1")

  @roster = erb :roster, :layout => false

  erb :js, :layout => false
end

class User
  def self.valid_username?(username)
    (/\A\w+\z/ =~ username)
  end  

  attr_reader :username, :name, :avatar, :error, :tweets, :extra

  def initialize(username='')
    @username = username
    if /\A(\w+)\[(.+)\]\z/ =~ @username
      @username = $1
      @extra = $2
    end
    @loaded = false
  end
  
  def valid?
    load
    @valid
  end
  
  def invalid(message)
    @error = message
    @valid = false
  end
  
  def load
    return if @loaded

    @loaded = @valid = true
    return invalid("We can only currently rosterize usernames with letters, numbers, and/or '_' in them.") unless User.valid_username?(@username)

    timeline = Twitter.user_timeline(@username)
    user = timeline.first["user"]

    @name = user["name"]
    @avatar = user["profile_image_url"]

    @tweets = timeline.collect{|e| e["text"]}
  rescue Twitter::Error => e
    return invalid(e.message)
  end
  
  def as_param
    r = "u=#{username}"
    if extra
      r << URI.escape("[#{extra}]")
    end
    r
  end
end

class Twitter
  include HTTParty
  base_uri 'twitter.com'
  
  class Error < StandardError; end
  
  def self.user_timeline(user)
    cache(user) do
      response = get("/statuses/user_timeline/#{user}.json")
      if response.code.to_i != 200 && error = response["error"]
        raise Error.new("Error getting the timeline for #{user}: #{error}.")
      end
      response
    end
  end
  
  def self.cache(key)
    key = key.gsub(/\W+/, '')
    (cache_read(key) || cache_write(key, yield))
  end
  
  def self.cache_read(key)
    filename = CACHE_DIR + "/twitter/#{key}"
    if File.exist?(filename) && File.mtime(filename) > (Time.now - (TWITTER_CACHE_EXPIRY))
      Crack::JSON.parse(File.read(filename))
    else
      nil
    end
  end
  
  def self.cache_write(key, response)
    File.open(CACHE_DIR + "/twitter/#{key}", 'w'){|f| f.write(response.body)}
    response
  end
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  def auto_link_urls(text) # Adapted from Rails 2.3.2
    text.gsub(%r{(https?://|www\.)[^\s<]+}) do
      href = $&
      punctuation = ''
      left, right = $`, $'
      # detect already linked URLs and URLs in the middle of a tag
      if left =~ /<[^>]+$/ && right =~ /^[^>]*>/
        # do not change string; URL is alreay linked
        href
      else
        # don't include trailing punctuation character as part of the URL
        if href.sub!(/[^\w\/-]$/, '') and punctuation = $& and opening = {']' => '[', ')' => '(', '}' => '{'}[punctuation]
          if href.scan(opening).size > href.scan(punctuation).size
            href << punctuation
            punctuation = ''
          end
        end

        link_text = block_given?? yield(href) : href
        href = 'http://' + href unless href.index('http') == 0

        (%(<a href=#{href}>#{h(link_text)}</a>) + punctuation)
      end
    end
  end
end