require 'sinatra'
require 'active_record'
require 'digest/sha2'
require 'cgi'

set :environment, :production
set :session_store, Rack::Session::Cookie

set :sessions,
  expire_after: 7200,
  secret: 'abcdefghij0123456789'

ActiveRecord::Base.configurations = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection :development

class BBSdata < ActiveRecord::Base
  self.table_name = 'bbsdata'
end

class Account < ActiveRecord::Base
  self.table_name = 'account'
end

get '/' do
  redirect '/login'
end

get '/login' do
  erb :login
end

get '/logout' do
  session.clear
  erb :logout
end

get '/loginfailure' do
  session.clear
  erb :loginfailure
end

post '/auth' do
  user = CGI.escapeHTML(params[:uname])
  pass = CGI.escapeHTML(params[:pass])
  r = checkLogin(user, pass)
  if r == 1
    session[:username] = user
    redirect '/contents'
  end
  redirect '/loginfailure'
end

get '/contents' do
  @u = session[:username]
  if @u == nil
    redirect '/badrequest'
  end

  begin
    page = params[:page] == nil ? 0 : params[:page].to_i - 1
  rescue
    page = 0
  end

  # 取得制限
  limit = 5

  a = BBSdata.all
  all_pages = (a.count.to_f / limit).ceil
  if page > all_pages
    redirect '/contents'
  else
    @p = ""
    @p += "<ul class=\"page\">"
    (1..all_pages).each do |ai|
      @p += "<li>"
      @p += "<a href=\"/contents?page=#{ai}\">#{ai}</a>"
      @p += "</li>"
    end
    @p += "</ul>"
  end

  if a.count == 0
    @t = "<tr><td>No entries in this BBS.</td></tr>"
  else
    @t = ""
    # ページネーション
    aa = a.limit(limit).offset(limit * page)

    aa.each do |b|
      @t += "<tr>"
      @t += "<td>#{b.id}</td>"
      @t += "<td>#{b.userid}</td>"
      @t += "<td>#{Time.at(b.writedata)}</td>"
      if b.userid == @u
        @t += "<td><form action=\"/delete\" method=\"post\">"
        @t += "<input type=\"hidden\" name=\"id\" value=\"#{b.id}\">"
        @t += "<input type=\"hidden\" name=\"_method\" value=\"delete\">"
        @t += "<input type=\"submit\" value=\"DELETE\"></form></td>"
      else
        @t += "<td></td>"
      end
      @t += "</tr>"
      @t += "<tr><td colspan=\"4\">#{b.entry}</td></tr>\n"
    end
  end
  erb :contents
end

get '/badrequest' do
  erb :badrequest
end

post '/new' do
  maxid = 0
  a = BBSdata.all
  a.each do |b|
    if b.id > maxid
      maxid = b.id
    end
  end

  s = BBSdata.new
  s.id = maxid + 1
  s.userid = session[:username]
  s.entry = CGI.escapeHTML(params[:entry])
  s.writedata = Time.now.to_i
  s.save

  redirect '/contents'
end

delete '/delete' do
  begin
    s = BBSdata.find(params[:id])
    s.destroy
  rescue => e
  end
  redirect '/contents'
end


def checkLogin(trial_username, trial_password)
  r = 0 #login failure
  begin
    a = Account.find(trial_username)
    db_username = a.id
    db_salt = a.salt
    db_hashed = a.hashed
    trial_hashed = Digest::SHA256.hexdigest(trial_password + db_salt)

    if trial_hashed == db_hashed
      r = 1 # login success
    end

  rescue => e
    r = 2
  end
  return (r)
end
