# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require 'sinatra/content_for'

require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
	require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && 
    todos_remaining_count(list).zero?    
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select {|todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition {|list| list_complete?(list) }

    incomplete_lists.each(&block) 
    complete_lists.each(&block) 
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition {|todo| todo[:completed] }

    incomplete_todos.each {|todo| yield todo, todos.index(todo)}
    complete_todos.each {|todo| yield todo, todos.index(todo) }
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

get '/' do
  redirect '/lists'
end

# View all lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists
end

# Render the new list form
get '/lists/new' do
  erb :new_list
end

# Return an error message if the list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

# Return error for message for invalid todo item names
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
  end
end

def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Display individual list
get '/lists/:num' do
  id = params[:num].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :individual_list
end

# Update completion status of a todo
post '/lists/:num/todos/:todo_index' do
  @list_id = params[:num].to_i
  @list = load_list(@list_id)  
  todo_id = params[:todo_index].to_i
  is_completed = (params[:completed] == 'true')
  
  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Delete a list
post '/lists/:num/destroy' do 
  @list_id = params[:num].to_i
  
  @storage.delete_list(@list_id)

  session[:success] = 'The list has been deleted.'
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists' 
  else
    redirect '/lists'
  end
end

# Mark all todos complete for a list 
post '/lists/:num/complete_all_tasks' do
  @list_id = params[:num].to_i
  @list = @storage.all_lists[@list_id]

  @storage.mark_all_todos_as_completed(@list_id)

  session[:success] = "All todo items have been completed."

  redirect "/lists/#{@list_id}"

end

# Update existing to do list
post '/lists/:num' do
  list_name = params[:list_name].strip
  @list_id = params[:num].to_i
  @list = load_list(@list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Edit an existing list
get '/lists/:num/edit' do
  @list_id = params[:num].to_i
  @list = load_list(@list_id)
  @name_of_list = @list[:name]
  erb :edit_list
end

# Add a todo list item
post '/lists/:num/todos' do 
  @list_id = params[:num].to_i
  @list = load_list(@list_id)
  text = params[:todo_item].strip
  
  error = error_for_todo(text)

  if error 
    session[:error] = error
  else
    @storage.create_new_todo(@list_id, text)
       
    session[:success] = "Todo item added successfully!"
    redirect '/lists/' + params[:num]
  end

  erb :individual_list
end

# Delete a task
post '/lists/:num/todos/:todo_index/destroy' do
  @list_id = params[:num].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_index].to_i

  @storage.delete_todo_from_list(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end
