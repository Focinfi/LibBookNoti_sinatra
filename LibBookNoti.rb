require 'sinatra'
require './lib_book_kit.rb'
set :server, %w[WEBrick]
set :port, 1024
set :bind, 'localhost'
get '/borrowed_books' do
	params[:user_number] ||= ""
	params[:user_passwd] ||= ""
	BookListReader.new.borrowed_book_list(params[:user_number], params[:user_passwd])
end

get '/renew_book' do 
	params[:user_number] ||= ""
	params[:user_passwd] ||= ""
	params[:book_id] ||= ""
	BookListReader.new.renew(params[:user_number], params[:user_passwd], params[:book_id])
end