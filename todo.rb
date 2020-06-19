# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = session[:lists]
 # @all_list_titles = session[:name]
  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:num' do
  @index = params[:num].to_i
  @name_of_list = session[:lists][@index][:name]
  @todos = session[:lists][@index][:todos]
  erb :individual_list
end

post '/lists/:num' do 
  @index = params[:num].to_i
  todo_item = params[:todo_item].strip
  
  if todo_item.empty? 
    session[:error] = "Todo item cannot be blank."
  else
    session[:lists][@index][:todos] << todo_item
    session[:success] = "Todo item added successfully!"
  end

  redirect 'lists/' + params[:num]
  erb :individual_list
end
