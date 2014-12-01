require 'net/http'
require 'nokogiri'

module ParaseBookListDoc
	def book_list_doc(html_str = "", book_list_path = "#mylib_content table tr")
		begin 
			Nokogiri::Slop(html_str).div(css: book_list_path)
		rescue Exception
			nil
		end	
	end

	def list_titles_from(doc)
		#(doc.shift.td.map { |t| t.content }).first(7)
    ['book_id', 'title', 'author', 'borrowed_date', 'return_date', 'lib_location', 'attachment']
	end

	def book_list_arr_form(doc)
		book_list_arr = []
		doc.each do |item|
			tds = item.td
			tds.pop
			book_list_arr << tds.map.with_index { |t, i| t.content }
		end

		book_list_arr
	end
end	

module Login
	def login(number, passwd)
		number ||= ""
		passwd ||= ""
		login_uri = 
			URI("http://202.119.228.6:8080/reader/redr_verify.php?select=cert_no&number=" +
				number +
				"&passwd=" + 
				passwd)			
		res = Net::HTTP.get_response(login_uri)
		@cookie = res['Set-Cookie']
	end

	def cookie
		@cookie
	end
end

module GetListDoc
	include Login

	def get_list_doc(url, cookie)
		http = Net::HTTP.new("202.119.228.6", 8080)
		path = '/reader/book_lst.php'

		headers = {
			'Cookie' => cookie
		}

		http.post(path, nil, headers).body
	end

end

module RenewBook
	def renew_book(url, cookiem, book_id)
		http = Net::HTTP.new("202.119.228.6", 8080)
		path = '/reader/ajax_renew.php?'
		headers = { 'Cookie' => cookie }
		data = 'bar_code=' + book_id
		html_str = http.post(path, data, headers).body
		Nokogiri::HTML(html_str).xpath('//font').text
	end
end

module MakeJsonFormat
	def make_json_from(list, titles)
		result = "[";
		list.each_with_index do |item, index|
			result << "{"
			item.each_with_index do |value, index|
        result << '"' << titles[index] << '"' << ":" << '"' <<  value << '"' if value
				result << "," unless index == 6
				# puts value
			end
			result << "},"
			# puts item.class
		end
		result << "]"
		result.gsub!(/,\]/, "]")
	end
end

module BookListKit
	include Login, GetListDoc, ParaseBookListDoc, RenewBook, MakeJsonFormat
end

class  BookListReader
	include BookListKit

	def borrowed_book_list(num, passwd)
		html_str = get_list_doc(nil, login(num, passwd))
		doc = book_list_doc(html_str)
		titles = list_titles_from(doc) if doc
		entries = book_list_arr_form(doc) if doc
		make_json_from(entries, titles) if entries
		# File.open('./lib_book_list.html').to_s
	end

	def renew(num, passwd, book_id)
		renew_book(nil, login(num, passwd), book_id)
	end

end

