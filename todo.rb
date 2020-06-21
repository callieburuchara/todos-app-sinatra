# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def next_element_id(elements)
    max = elements.map { |todo| todo[:id] }.max || 0
    max + 1
  end

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

    incomplete_lists.each {|list| yield list, lists.index(list)}
    complete_lists.each {|list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition {|todo| todo[:completed] }

    incomplete_todos.each {|todo| yield todo, todos.index(todo)}
    complete_todos.each {|todo| yield todo, todos.index(todo) }
  end
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
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

# Return error for message for invalid todo item names
def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo must be between 1 and 100 characters.'
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
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Display individual list
get '/lists/:num' do
  @list_id = params[:num].to_i
  @name_of_list = session[:lists][@list_id][:name]
  @list = session[:lists][@list_id]
  erb :individual_list
end

# Update completion status of a todo
post '/lists/:num/todos/:todo_index' do
  @list_id = params[:num].to_i
  @list = session[:lists][@list_id]
  
  todo_id = params[:todo_index].to_i
  is_completed = (params[:completed] == 'true')
  
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Delete a list
post '/lists/:num/destroy' do 
  @list_id = params[:num].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# Mark all todos complete for a list 
post '/lists/:num/complete_all_tasks' do
  @list_id = params[:num].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todo items have been completed."

  redirect "/lists/#{@list_id}"

end

# Update existing to do list
post '/lists/:num' do
  list_name = params[:list_name].strip
  @list_id = params[:num].to_i
  @list = session[:lists][@list_id]


  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name   
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Edit an existing list
get '/lists/:num/edit' do
  @list_id = params[:num].to_i
  @name_of_list = session[:lists][@list_id][:name]
  erb :edit_list
end

# Add a todo list item
post '/lists/:num/todos' do 
  @list_id = params[:num].to_i
  @list = session[:lists][@list_id]
  text = params[:todo_item].strip
  
  error = error_for_todo(text)
  if error 
    session[:error] = error
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "Todo item added successfully!"
  end

  redirect '/lists/' + params[:num]
  erb :individual_list
end

# Delete a task
post '/lists/:num/todos/:todo_index/destroy' do
  @list_id = params[:num].to_i
  session[:lists][@list_id][:todos].delete_at(params[:todo_index].to_i)
  session[:success] = 'The todo item has been deleted.'
  redirect "/lists/#{@list_id}"
end

