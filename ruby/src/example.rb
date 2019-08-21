# frozen_string_literal: true

require 'sinatra'
require 'base'

client =
  Base::Client.new(access_token: '4dcfbd28-ae85-4370-9529-45cced846cba')

def get_error_message(error)
  case error
  when Base::Unauthorized
    'Unauthorized!'
  when Base::InvalidRequest
    error.data['error']
  when Base::UnkownError
    'Something went wrong!'
  else
    'Something went wrong!'
  end
end

set :erb, layout: :layout
enable :sessions

get '/' do
  erb :index
end

# LOGIN
# ==============================================================================

get '/login' do
  if session[:user]
    redirect '/'
  else
    erb :login, locals: { error: nil }
  end
end

post '/login' do
  if session[:user]
    redirect '/'
  else
    user =
      client.sessions.authenticate(
        password: params['password'],
        email: params['email']
      )

    session[:user] = user.id

    redirect "/users/#{user.id}"
  end
rescue StandardError => e
  erb :login, locals: { error: e }
end

# REGISTER
# ==============================================================================

get '/register' do
  if session[:user]
    redirect '/'
  else
    erb :register, locals: { error: nil }
  end
end

post '/register' do
  if session[:user]
    redirect '/'
  else
    user =
      client.users.create(
        confirmation: params[:confirmation],
        password: params[:password],
        email: params[:email]
      )

    session[:user] = user.id

    redirect "/users/#{user.id}"
  end
rescue StandardError => e
  erb :register, locals: { error: e }
end

# LOGOUT
# ==============================================================================

get '/logout' do
  session[:user] = nil

  redirect '/'
end

# USER
# ==============================================================================

get '/users/:id' do
  user =
    client.users.get(params['id'])

  erb :user, locals: { user: user }
rescue StandardError
  redirect '/'
end

post '/users/:id/delete' do
  client.users.delete(params['id'])

  session[:user] = nil if session[:user] == params['id']

  redirect '/'
rescue StandardError
  redirect '/'
end

# SEND EMAIL
# ==============================================================================

get '/send-email' do
  erb :send_email, locals: { error: nil, success: nil }
end

post '/send-email' do
  client.emails.send(
    subject: params[:subject],
    from: params[:from],
    text: params[:text],
    html: params[:html],
    to: params[:to]
  )

  erb :send_email, locals: { error: nil, success: true }
rescue StandardError => e
  erb :send_email, locals: { error: e, success: nil }
end

# UPLOAD FILE
# ==============================================================================

get '/upload-file' do
  erb :upload_file, locals: { error: nil }
end

post '/upload-file' do
  file =
    client.files.create(
      path: params[:file][:tempfile].path,
      filename: params[:file][:filename],
      type: params[:file][:type]
    )

  redirect "/files/#{file.id}"
rescue StandardError => e
  erb :upload_file, locals: { error: e }
end

# FILE
# ==============================================================================

get '/files/:id' do
  file =
    client.files.get(params['id'])

  erb :file, locals: { file: file }
rescue StandardError
  redirect '/'
end

post '/files/:id/delete' do
  client.files.delete(params['id'])

  redirect '/'
rescue StandardError
  redirect '/'
end

# UPLOAD IMAGE
# ==============================================================================

get '/upload-image' do
  erb :upload_image, locals: { error: nil }
end

post '/upload-image' do
  image =
    client.images.create(
      path: params[:image][:tempfile].path,
      filename: params[:image][:filename],
      type: params[:image][:type]
    )

  redirect "/images/#{image.id}"
rescue StandardError => e
  erb :upload_file, locals: { error: e }
end

# IMAGE
# ==============================================================================

get '/images/:id' do
  image =
    client.images.get(params['id'])

  erb :image, locals: { image: image }
rescue StandardError
  redirect '/'
end

post '/images/:id/delete' do
  client.images.delete(params['id'])

  redirect '/'
rescue StandardError
  redirect '/'
end
