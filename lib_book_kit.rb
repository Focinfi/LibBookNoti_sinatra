# encoding utf-8
require 'net/http'
require 'nokogiri'

module ParaseHtml
	def html_login?(html_str = "")
		return html_str.match(/caption/).nil?
	end

	def html_cookie_ok?(html_str = "")
		return !html_str.match(/logout\.php/).nil?
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
    %w{ 
     book_id
     title
     author
     borrowed_date
     return_date
     lib_location
     attachment
     description
    }
	end

	def book_list_arr_form(doc)
		href_list = book_href_list_from(doc)
		book_list_arr = []
    doc.shift
		doc.each_with_index do |item, index|
			tds = item.td
			tds.pop
			book_list_arr << tds.map { |t| t.content.strip }
			book_list_arr[index] << book_description_str(get_book_detail_doc href_list[index])
		end

		book_list_arr
	end

	def book_href_list_from(doc)
		book_href_list = []
		doc.shift
		doc.each do |item|
			# book_href_list << item.td[1].child.methods.grep(/attr/) { |match| match }
			href = "http://202.119.228.6:8080" << item.td[1].child.attr(:href).gsub(/^\.\./, "")
			book_href_list << href
		end
		book_href_list
	end	

	def book_description_str(doc)
		desc = Nokogiri::Slop(doc).div(css: "#s_c_left .booklist dd")[-2].content
	end

end

module Login
	def login(number, passwd)
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
		# return html_login?(res.body).to_s
		# res.body
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

	def get_book_detail_doc(href)
		Net::HTTP.get_response(URI(href)).body
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
				result << ","
			end
			result << "},"
		end
		
		result << "]"
		result.gsub!(/,\]/, "]")
		result.gsub!(/,\}/, "}")
	end

	def enclose_hash_josn(hash)
		key, value = hash.to_a.first[0].to_s, hash.to_a.first[1]
		enclose_word(key) << ":" << enclose_word(value) 
	end

	def enclose_word(word = nil)
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
		unless html_cookie_ok?(html_str)
			return json_body_wrapper("401", "Expired Cookie", 
							 enclose_word("book_list") << ":" << "null")
		end

		doc = book_list_doc(html_str)
		titles = list_titles_from if doc
		entries = book_list_arr_form(doc) if doc
    
  	book_list =  entries.nil? ? "null" : book_list_json(entries, titles)

		json_body_wrapper("200", "Get Book List Succeed", 
			enclose_word("book_list") << ":" << book_list) 
		# book_href_list_from(doc)
  end

	def renew(cookie, book_id)
		result = renew_book(nil, cookie, book_id)

		if result.length == 0
			return json_body_wrapper("401", "Expired Cookie", 
							 enclose_word("renew_book_result") << ":" << "null")
		end
		
		json_body_wrapper("200", "Get Renew Book Result Succeed", 
      enclose_hash_josn("renew_book_result" => result))
	end

	# def test_book_detail_list
		
	# end

end

