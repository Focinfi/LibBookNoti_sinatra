require 'sinatra'
require './lib_book_kit.rb'
set :server, %w[thin]
set :port, 1025
# set :bind, '121.40.83.163'

get '/login' do 
	params[:user_number] ||= ""
	params[:user_passwd] ||= ""	
	BookListReader.new.login(params[:user_number], params[:user_passwd])
end

get '/borrowed_books' do
	params[:cookie] ||= ""
	BookListReader.new.borrowed_book_list(params[:cookie])
end

get '/renew_book' do 
	params[:cookie]
	params[:book_id] ||= ""
	BookListReader.new.renew(params[:cookie], params[:book_id])
end
