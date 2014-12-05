require 'net/http'
require 'nokogiri'

module ParaseHtml
	def html_login?(html_str = "")
		result = html_str.match(/caption/).nil?
	end

	def book_list_doc(html_str = "", book_list_path = "#mylib_content table tr")
		begin 
			Nokogiri::Slop(html_str).div(css: book_list_path)
		rescue Exception
			nil
		end	
	end

	def list_titles_from(doc = nil)
    #(doc.shift.td.map { |t| t.content }).first(7)
    ['book_id', 'title', 'author', 'borrowed_date', 'return_date', 'lib_location', 'attachment']
	end

	def book_list_arr_form(doc)
		book_list_arr = []
    doc.shift
		doc.each do |item|
			tds = item.td
			tds.pop
			book_list_arr << tds.map.with_index { |t, i| t.content.strip }
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
		
		if (html_login? res.body)
			json_body_wrapper("200", "Login Succeed", 
				enclose_hash_josn("cookie" => @cookie))
		else
			json_body_wrapper("401", "Login Fail", 
				enclose_hash_josn("cookie" => nil))
		end
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
	def renew_book(url, cookie, book_id)
		http = Net::HTTP.new("202.119.228.6", 8080)
		path = '/reader/ajax_renew.php?'
		headers = { 'Cookie' => cookie }
		data = 'bar_code=' + book_id
		html_str = http.post(path, data, headers).body
		Nokogiri::HTML(html_str).xpath('//font').text
	end
end

module MakeJsonFormat
	def json_body_wrapper(code, message, body)
		"{" <<
			enclose_hash_josn("code" => code) << "," << 
			enclose_hash_josn("message" => message) << "," << 
			enclose_word("body") << ":" << enclose_object(body) << 
			"}"
	end

	def book_list_json(list, titles)
		result = "[";
		list.each_with_index do |item, index|
			result << "{"
			item.each_with_index do |value, index|
        result << enclose_hash_josn(titles[index] => value) if value
				result << "," unless index == 6
			end
			result << "},"
		end
		
		result << "]"
		result.gsub!(/,\]/, "]")
	end

	def enclose_hash_josn(hash)
		key, value = hash.to_a.first[0].to_s, hash.to_a.first[1]
		enclose_word(key) << ":" << enclose_word(value) 
	end

	def enclose_word(word = nil)
		# "\"#{word}\""
		return "\"#{word}\"" if word
		"null"
	end

	def enclose_object(string = nil)
		return "{#{string}}" if string
		"null"			
	end
end

module BookListKit
	include Login, GetListDoc, ParaseHtml, RenewBook, MakeJsonFormat
end

class  BookListReader
	include BookListKit

	def borrowed_book_list(cookie)
		html_str = get_list_doc(nil, cookie)
		if(html_login?(html_str))
			return json_body_wrapper("401", "Login Fail", 
							 enclose_word("book_list") << ":" << "null")
		end

		doc = book_list_doc(html_str)
		titles = list_titles_from if doc
		entries = book_list_arr_form(doc) if doc
    
    if entries
      book_list = book_list_json(entries, titles)
    else
      book_list = "null"
    end

		json_body_wrapper("200", "book_list_json", 
			enclose_word("book_list") << ":" << book_list) 
  end

	def renew(cookie, book_id)
		result = renew_book(nil, cookie, book_id)

		if result.length == 0
			return json_body_wrapper("401", "Login Fail", 
							 enclose_word("renew_book_result") << ":" << "null")
		end
		
		json_body_wrapper("200", "renew_book_json", 
      enclose_hash_josn("renew_book_result" => result))
	end

end

