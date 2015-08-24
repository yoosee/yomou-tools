#!/usr/bin/ruby
#
#

require 'rubygems'
require 'nokogiri'
require 'open-uri'

yomou_url = 'http://ncode.syosetu.com/'

fetch_wait = 5

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

page_url = nil
yomou_code = nil

arg = ARGV.shift
if /^#{yomou_url}([^\/]+?)\// =~ arg
  url = arg.to_s
  yomou_code = $1.to_s
else
  # e.g. n4202cb
  yomou_code = arg
  url = yomou_url + yomou_code + '/'
end

page = Nokogiri::HTML(open(url))
title = page.title

# <div class="novel_writername">
# 作者：<a href="http://mypage.syosetu.com/445622/">棚花尋平</a>
# </div><!--novel_writername-->
author = page.css('div.novel_writername').first.css('a').first.content.gsub(/[\/\s]/,'')

puts "Checking #{title} [#{author}]"

# text fetch url
# <li><a href="http://ncode.syosetu.com/txtdownload/top/ncode/534149/" onclick="javascript:window.open('http://ncode.syosetu.com/txtdownload/top/ncode/534149/','a','width=600,height=450'); return false;">TXTダウンロード</a></li>
text_ncode = nil
page.css('div#novel_footer').first.css('li').each do |li|
  href = li.css('a').first.attribute('href').value
  if /txtdownload\/top\/ncode\/(\d+?)\// =~ href
    text_ncode = $1
  end
end

unless text_ncode
  puts "cannot get ncode"
  exit
end

latest_number = 0
page.css('dd.subtitle > a').each do |subtitle_url|
  if /\/#{yomou_code}\/(\d+?)\// =~ subtitle_url.attribute('href').value
    n = $1.to_i
    latest_number = n > latest_number ? n : latest_number
  end
end

book_directory = "./#{title} [#{author}]"
work_directory = "#{book_directory}/work/"

if File.directory? work_directory
else
  FileUtils.mkdir_p work_directory
end

latest_file_number = 0
Dir.open(work_directory).each do |file|
  if /(\d+?)\.txt/ =~ file
    n = $1.to_i
    latest_file_number = n > latest_file_number ? n : latest_file_number
  end
end

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

