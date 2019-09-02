require "base"
require "kemal"
require "kemal-session"

client =
  Base::Client.new(access_token: "c8d4600b-6334-4b1c-8b5c-63722a923f60", url: "http://localhost:8080")

Kemal::Session.config do |config|
  config.cookie_name = "session_id"
  config.secret = "some_secret"
  config.gc_interval = 2.minutes
end

def logged_in?(env)
  env.session.string?("user")
end

def get_error_message(error)
  case error
  when Base::Unauthorized
    "Unauthorized!"
  when Base::InvalidRequest
    error.data.error
  when Base::UnkownError
    "Something went wrong: #{error.error}"
  else
    "Something went wrong!"
  end
end

get "/" do |env|
  render "src/views/index.ecr", "src/views/layout.ecr"
end

# LOGIN
# ==============================================================================

get "/login" do |env|
  if logged_in?(env)
    env.redirect "/"
  else
    password = ""
    email = ""
    error = nil

    render "src/views/login.ecr", "src/views/layout.ecr"
  end
end

post "/login" do |env|
  if logged_in?(env)
    env.redirect "/"
  else
    password =
      env.params.body["password"].as(String)

    email =
      env.params.body["email"].as(String)

    user =
      client.sessions.authenticate(
        password: password,
        email: email)

    env.session.string("user", user.id)
    env.redirect "/users/#{user.id}"
  end
rescue error
  render "src/views/login.ecr", "src/views/layout.ecr"
end

# REGISTER
# ==============================================================================

get "/register" do |env|
  if logged_in?(env)
    env.redirect "/"
  else
    confirmation = ""
    custom_data = ""
    password = ""
    email = ""
    error = nil

    render "src/views/register.ecr", "src/views/layout.ecr"
  end
end

post "/register" do |env|
  if logged_in?(env)
    env.redirect "/"
  else
    confirmation =
      env.params.body["confirmation"].as(String)

    password =
      env.params.body["password"].as(String)

    email =
      env.params.body["email"].as(String)

    custom_data =
      env.params.body["custom_data"].as(String)

    custom_data =
      if custom_data.strip.empty?
        "null"
      else
        JSON.parse(custom_data)
      end

    user =
      client.users.create(
        confirmation: confirmation,
        custom_data: custom_data,
        password: password,
        email: email)

    env.session.string("user", user.id)
    env.redirect "/users/#{user.id}"
  end
rescue error
  render "src/views/register.ecr", "src/views/layout.ecr"
end

# LOGOUT
# ==============================================================================

get "/logout" do |env|
  env.session.delete_string("user")
  env.redirect "/"
end

# USER
# ==============================================================================

get "/users" do |env|
  page =
    env.params.query["page"]?.try(&.to_i32) || 1

  data =
    client.users.list(page: page)

  render "src/views/users.ecr", "src/views/layout.ecr"
end

get "/users/:id" do |env|
  user =
    client.users.get(env.params.url["id"]?.to_s)

  render "src/views/user.ecr", "src/views/layout.ecr"
rescue
  env.redirect "/"
end

get "/users/:id/update" do |env|
  error = nil

  id =
    env.params.url["id"]?.to_s

  user =
    client.users.get(id)

  email =
    user.email

  custom_data =
    user.custom_data

  render "src/views/update_user.ecr", "src/views/layout.ecr"
rescue
  env.redirect "/"
end

post "/users/:id" do |env|
  id =
    env.params.url["id"]?.to_s

  user =
    client.users.get(id)

  email =
    env.params.body["email"].as(String)

  custom_data =
    env.params.body["custom_data"].as(String)

  custom_data =
    if custom_data.strip.empty?
      "null"
    else
      JSON.parse(custom_data)
    end

  begin
    client.users.update(
      custom_data: custom_data,
      email: email,
      id: user.id)

    env.redirect "/users/#{user.id}"
  rescue e
    error =
      get_error_message(e)

    render "src/views/update_user.ecr", "src/views/layout.ecr"
  end
rescue
  env.redirect "/"
end

post "/users/:id/delete" do |env|
  client.users.delete(env.params.url["id"]?.to_s)

  if env.session.string?("user") == env.params.url["id"]?
    env.session.delete_string("user")
  end

  env.redirect "/users"
rescue
  env.redirect "/users"
end

# SEND EMAIL
# ==============================================================================

get "/send-email" do |env|
  success = false
  error = nil

  subject = ""
  from = ""
  html = ""
  text = ""
  to = ""

  render "src/views/send-email.ecr", "src/views/layout.ecr"
end

post "/send-email" do |env|
  subject =
    env.params.body["subject"].as(String)

  from =
    env.params.body["from"].as(String)

  html =
    env.params.body["html"].as(String)

  text =
    env.params.body["text"].as(String)

  to =
    env.params.body["to"].as(String)

  email =
    client.emails.send(
      subject: subject,
      from: from,
      text: text,
      html: html,
      to: to)

  success = true
  error = nil

  render "src/views/send-email.ecr", "src/views/layout.ecr"
rescue error
  render "src/views/send-email.ecr", "src/views/layout.ecr"
end

# UPLOAD FILE
# ==============================================================================

get "/upload-file" do |env|
  error = nil

  render "src/views/upload-file.ecr", "src/views/layout.ecr"
end

post "/upload-file" do |env|
  file =
    client.files.create(
      file: env.params.files["file"].tempfile)

  env.redirect "/files/#{file.id}"
rescue error
  render "src/views/upload-file.ecr", "src/views/layout.ecr"
end

# FILE
# ==============================================================================

get "/files" do |env|
  page =
    env.params.query["page"]?.try(&.to_i32) || 1

  data =
    client.files.list(page: page)

  render "src/views/files.ecr", "src/views/layout.ecr"
end

get "/files/:id" do |env|
  file =
    client.files.get(env.params.url["id"]?.to_s)

  render "src/views/file.ecr", "src/views/layout.ecr"
rescue
  env.redirect "/"
end

post "/files/:id/delete" do |env|
  client.files.delete(env.params.url["id"]?.to_s)

  env.redirect "/files"
rescue
  env.redirect "/files"
end

# UPLOAD IMAGE
# ==============================================================================

get "/images" do |env|
  page =
    env.params.query["page"]?.try(&.to_i32) || 1

  data =
    client.images.list(page: page)

  render "src/views/images.ecr", "src/views/layout.ecr"
end

get "/upload-image" do |env|
  error = nil

  render "src/views/upload-image.ecr", "src/views/layout.ecr"
end

post "/upload-image" do |env|
  image =
    client.images.create(
      image: env.params.files["image"].tempfile)

  env.redirect "/images/#{image.id}"
rescue error
  render "src/views/upload-image.ecr", "src/views/layout.ecr"
end

# IMAGE
# ==============================================================================

get "/images/:id" do |env|
  image =
    client.images.get(env.params.url["id"]?.to_s)

  render "src/views/image.ecr", "src/views/layout.ecr"
rescue
  env.redirect "/"
end

post "/images/:id/delete" do |env|
  client.images.delete(env.params.url["id"]?.to_s)

  env.redirect "/images"
rescue
  env.redirect "/images"
end

# MAILING LISTS
# ==============================================================================

get "/mailing-lists" do |env|
  page =
    env.params.query["page"]?.try(&.to_i32) || 1

  data =
    client.mailing_lists.list(page: page)

  render "src/views/mailing-lists.ecr", "src/views/layout.ecr"
end

get "/mailing-lists/:id" do |env|
  list =
    client.mailing_lists.get(env.params.url["id"]?.to_s)

  render "src/views/mailing-list.ecr", "src/views/layout.ecr"
rescue
  env.redirect "/"
end

post "/mailing-lists/:id/subscribe" do |env|
  id =
    env.params.url["id"]?.to_s

  email =
    env.params.body["email"].as(String)

  list =
    client
      .mailing_lists
      .subscribe(id: id, email: email)

  env.redirect "/mailing-lists/#{id}"
rescue
  env.redirect "/"
end

post "/mailing-lists/:id/unsubscribe" do |env|
  id =
    env.params.url["id"]?.to_s

  email =
    env.params.body["email"].as(String)

  list =
    client
      .mailing_lists
      .unsubscribe(id: id, email: email)

  env.redirect "/mailing-lists/#{id}"
rescue
  env.redirect "/"
end

post "/mailing-lists/:id/send" do |env|
  id =
    env.params.url["id"]?.to_s

  from =
    env.params.body["from"].as(String)

  subject =
    env.params.body["subject"].as(String)

  html =
    env.params.body["html"].as(String)

  text =
    env.params.body["text"].as(String)

  list =
    client
      .mailing_lists
      .send(id: id, from: from, subject: subject, html: html, text: text)

  env.redirect "/mailing-lists/#{id}"
rescue
  env.redirect "/"
end

Kemal.run
