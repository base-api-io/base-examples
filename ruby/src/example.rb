# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra'
require 'yaml'
require 'base'

client =
  Base::Client.new(access_token: "4dcfbd28-ae85-4370-9529-45cced846cba")

def get_error_message(error)
  case error
  when Base::Unauthorized
    'Unauthorized!'
  when Base::InvalidRequest
    error.data['error']
  when Base::UnkownError
    "Something went wrong: #{error.error}"
  else
    "Something went wrong: #{error}"
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
        password: params[:password],
        email: params[:email]
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
        custom_data: JSON.parse(params[:custom_data]),
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

get '/users' do
  page =
    params[:page]&.to_i || 1

  data =
    client.users.list(page: page)

  erb :users, locals: { data: data, page: page }
end

get '/users/:id' do
  user =
    client.users.get(params[:id])

  erb :user, locals: { user: user }
rescue StandardError
  redirect '/users'
end

get '/users/:id/update' do
  user =
    client.users.get(params[:id])

  erb :update_user, locals: { user: user, error: nil }
rescue StandardError
  redirect '/users'
end

post '/users/:id' do
  user =
    client.users.get(params[:id])

  custom_data =
    if params[:custom_data].empty?
      nil
    else
      JSON.parse(params[:custom_data])
    end

  client.users.update(
    custom_data: custom_data,
    email: params[:email],
    id: user.id
  )

  redirect "/users/#{user.id}"
rescue StandardError => e
  erb :update_user, locals: { error: e, user: user }
end

post '/users/:id/delete' do
  client.users.delete(params[:id])

  session[:user] = nil if session[:user] == params[:id]

  redirect '/users'
rescue StandardError
  redirect '/users'
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

get '/files' do
  page =
    params[:page]&.to_i || 1

  data =
    client.files.list(page: page)

  erb :files, locals: { data: data, page: page }
end

get '/files/:id' do
  file =
    client.files.get(params[:id])

  erb :file, locals: { file: file }
rescue StandardError
  redirect '/'
end

post '/files/:id/delete' do
  client.files.delete(params[:id])

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

get '/images' do
  page =
    params[:page]&.to_i || 1

  data =
    client.images.list(page: page)

  erb :images, locals: { data: data, page: page }
end

get '/images/:id' do
  image =
    client.images.get(params[:id])

  erb :image, locals: { image: image }
rescue StandardError
  redirect '/'
end

post '/images/:id/delete' do
  client.images.delete(params[:id])

  redirect '/'
rescue StandardError
  redirect '/'
end

# MAILING LISTS
# ==============================================================================

get "/mailing-lists" do
  page =
    params[:page]&.to_i || 1

  data =
    client.mailing_lists.list(page: page)

  erb :mailing_lists, locals: { data: data, page: page }
end

get "/mailing-lists/:id" do
  list =
    client.mailing_lists.get(params[:id])

  erb :mailing_list, locals: { list: list, client: client }
rescue
  redirect "/"
end

post "/mailing-lists/:id/subscribe" do
  list =
    client
      .mailing_lists
      .subscribe(
        id: params[:id],
        email: params[:email])

  redirect "/mailing-lists/#{params[:id]}"
rescue
  redirect "/"
end

post "/mailing-lists/:id/unsubscribe" do
  list =
    client
      .mailing_lists
      .unsubscribe(
        id: params[:id],
        email: params[:email])

  redirect "/mailing-lists/#{params[:id]}"
rescue
  redirect "/"
end

post "/mailing-lists/:id/send" do
  list =
    client
      .mailing_lists
      .send(
        subject: params[:subject],
        from: params[:from],
        html: params[:html],
        text: params[:text],
        id: params[:id])

  redirect "/mailing-lists/#{id}"
rescue
  redirect "/"
end

# FORMS
# ==============================================================================

get "/forms" do
  page =
    params[:page]&.to_i || 1

  data =
    client.forms.list(page: page)

  erb :forms, locals: { data: data, page: page }
end

get "/forms/create" do
  erb :form_create, locals: { error: nil }
end

post "/forms/create" do
  form =
    client.forms.create(
      name: params[:name])

  redirect "/forms/#{form.id}"
rescue error
  erb :form_create, locals: { error: error }
end

get "/forms/:id" do
  form =
    client.forms.get(params[:id])

  erb :form, locals: { form: form }
rescue
  redirect "/"
end

post "/forms/:id/delete" do
  client.forms.delete(params[:id])

  redirect "/forms"
rescue
  redirect "/forms"
end

get "/forms/:id/submissions" do
  form =
    client.forms.get(params[:id])

  page =
    params[:page]&.to_i || 1

  data =
    client.forms.submissions(id: params[:id], page: page)

  erb :form_submissions, locals: { data: data, page: page, form: form }
end

get "/forms/:id/submissions/:submission_id" do
  form =
    client.forms.get(params[:id])

  submission =
    client.forms.get_submission(params[:id], params[:submission_id])

  erb :form_submission, locals: { form: form, submission: submission }
end

post "/forms/:id/submissions/:submission_id/delete" do
  form_id =
    params[:id]

  client.forms.delete_submission(form_id, params[:submission_id])

  redirect "/forms/#{form_id}"
rescue
  redirect "/forms/#{form_id}"
end

get "/forms/:id/submit" do
  form =
    client.forms.get(params[:id])

  erb :form_submit, locals: { error: nil, form: form }
end

post "/forms/:id/submit" do
  form =
    client.forms.get(params[:id])

  submission =
    client.forms.submit(
      id: form.id,
      form: {"data" => params[:data]})

  redirect "/forms/#{form.id}/submissions/#{submission.id}"
rescue error
  erb :form_submit, locals: { error: error }
end
