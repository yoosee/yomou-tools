#!/usr/bin/ruby
# coding: utf-8
#
#

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'optparse'

def fetch_url url, filename
  open(filename, 'w') do |file|
    open(url) do |data|
      file.write data.read
    end
  end
end

def retryable(options = {}, &block)
  opts = { :tries => 1, :on => Exception, :wait => 3}.merge(options)
  retry_exception, retries, wait_time = opts[:on], opts[:tries], opts[:wait]
  begin
    return yield
  rescue retry_exception
    sleep wait_time
    retry if (retries -= 1) > 0
  end

  yield
end

def get_title_author page 
  title = page.title
# <div class="novel_writername">
# 作者：<a href="http://mypage.syosetu.com/445622/">棚花尋平</a>
# </div><!--novel_writername-->
  a = page.css('div.novel_writername')
  begin
    author = a.first.css('a').first.content.gsub(/[\/\s]/,'')
  rescue
    author = a.first.content.gsub(/作者：/,'').gsub(/[\/\s]/,'')
  end
  return title, author
end

def get_text_ncode page
# text fetch url
# <li><a href="http://ncode.syosetu.com/txtdownload/top/ncode/534149/" onclick="javascript:window.open('http://ncode.syosetu.com/txtdownload/top/ncode/534149/','a','width=600,height=450'); return false;">TXTダウンロード</a></li>
  text_ncode = nil 
  page.css('div#novel_footer').first.css('li').each do |li| 
    href = li.css('a').first.attribute('href').value 
    if /txtdownload\/top\/ncode\/(\d+?)\// =~ href 
      text_ncode = $1
    end
  end
  return text_ncode
end

def get_latest_article_number page, yomou_code
  latest_number = 0 
  page.css('dd.subtitle > a').each do |subtitle_url| 
    if /\/#{yomou_code}\/(\d+?)\// =~ subtitle_url.attribute('href').value 
      n = $1.to_i 
      latest_number = n > latest_number ? n : latest_number
    end
  end
  return latest_number
end


def get_latest_file_number dir 
  latest_file_number = 0 
  Dir.open(dir).each do |file| 
    if /(\d+?)\.txt/ =~ file 
      n = $1.to_i 
      latest_file_number = n > latest_file_number ? n : latest_file_number
    end
  end
  return latest_file_number
end

########
#

yomou_url = 'http://ncode.syosetu.com/'
fetch_wait = 5

page_url = nil
yomou_code = nil

arg = ARGV.shift
if /^#{yomou_url}([^\/]+?)\// =~ arg
  url = arg.to_s
  yomou_code = $1.to_s
elsif /^n[a-z0-9]+?/ =~ arg # e.g. n4202cb
  yomou_code = arg
  url = yomou_url + yomou_code + '/'
else
  puts "cannot parse args."
  exit
end

page = Nokogiri::HTML(open(url))

title, author = get_title_author page
puts "Checking #{title} [#{author}]"
text_ncode = get_text_ncode page
unless text_ncode
  puts "cannot get ncode"
  exit
end

book_directory = "./#{title} [#{author}]"
work_directory = "#{book_directory}/work/"
unless File.directory? work_directory
  FileUtils.mkdir_p work_directory
end

latest_number = get_latest_article_number page, yomou_code
latest_file_number = get_latest_file_number work_directory

puts "working in directory: #{work_directory}"
puts "latest article #{latest_number}, exists file #{latest_file_number}"

text_ncode_url = "http://ncode.syosetu.com/txtdownload/dlstart/ncode/#{text_ncode}/"

(latest_file_number+1 .. latest_number).each do |n|
  text_url_parameter = "?no=#{n}&hankaku=0&code=utf-8&kaigyo=CRLF" 
  text_url = "#{text_ncode_url}/#{text_url_parameter}"
  filename = "#{work_directory}/#{n}.txt"
  puts "fetch #{n}: #{text_url}"
  retryable(:tries => 3, :on => OpenURI::HTTPError, :wait => 10) do
    fetch_url text_url, filename
  end
  sleep fetch_wait
end

