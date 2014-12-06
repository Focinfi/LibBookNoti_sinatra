# encoding utf-8
require 'net/http'
require 'nokogiri'
require 'json'

module ParseHtml
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

  def list_titles
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
    # doc.shift
    doc.each_with_index do |item, index|
      tds = item.td
      tds.pop
      item_hash = {}
      tds.map.with_index { |t, i| item_hash[list_titles[i]] = t.content.strip }
      item_hash[list_titles.last] = book_description_str(get_book_detail_doc href_list[index])
      book_list_arr << item_hash
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
      res = get_login_res(login_uri)
    @cookie = res['Set-Cookie']		
		
    if (html_login? res.body)
      json_wrapper("200", "Login Succeed", { cookie: @cookie })
    else
      json_wrapper("401", "Login Fail", nil)
    end
  end

end

module GetHtmlStr

  def get_login_res(url)
    Net::HTTP.get_response(url)
  end

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

  def get_renew_result(url, cookie, book_id)
    http = Net::HTTP.new("202.119.228.6", 8080)
    path = '/reader/ajax_renew.php?'
    headers = { 'Cookie' => cookie }
    data = 'bar_code=' + book_id
    html_str = http.post(path, data, headers).body
    Nokogiri::HTML(html_str).xpath('//font').text
  end

end

module MakeJsonStr
  def json_wrapper(code, message, body)
    res_hash = {
      code: code,
      message: message,
      body: body
    }

    JSON.generate res_hash
  end
end

module BookListKit
  include Login, GetHtmlStr, ParseHtml, MakeJsonStr
end

class BookListReader
  include BookListKit

  def borrowed_book_list(cookie)
    html_str = get_list_doc(nil, cookie)
    
    unless html_cookie_ok?(html_str)
      return json_wrapper("401", "Expired Cookie", nil)
    end

    doc = book_list_doc(html_str)
    entries = book_list_arr_form(doc) if doc
    json_wrapper("200", "Get Book List Succeed", entries) 
  end
  

  def renew(cookie, book_id)
    result = get_renew_result(nil, cookie, book_id)

  if result.length == 0
    return json_wrapper("401", "Expired Cookie", nil)
  end		
    json_wrapper("200", "Get Renew Book Result Succeed", { renew_result: result })
  end
end

