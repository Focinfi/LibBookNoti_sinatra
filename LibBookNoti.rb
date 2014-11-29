require 'sinatra'
require './lib_book_kit.rb'

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