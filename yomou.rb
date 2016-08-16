#!/usr/bin/ruby
# coding: utf-8
#
#

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'optparse'


FETCH_WAIT = 15
N_RETRY = 4
YOMOU_BASE_URL = 'http://ncode.syosetu.com/'
TEXT_BASE_URL  = 'http://ncode.syosetu.com/txtdownload/dlstart/ncode/'

def fetch_url url, filename
  open(filename, 'w') do |file|
    open(url) do |data|
      file.write data.read
    end
  end
end

def retryable(options = {}, &block)
  opts = { :tries => 3, :on => Exception, :wait => 10}.merge(options)
  retry_exception, retries, wait_time = opts[:on], opts[:tries], opts[:wait]
  begin
    return yield
  rescue retry_exception
    puts "[Retry] on #{retry_exception.inspect} (#{retries}/#{opts[:tries]})"
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

def get_last_update page
  last_update = nil
  page.xpath("//meta[@name='WWWC']/@content").each do |attr|
    last_update = attr.to_s
  end
  last_update
end

def update_infofile filename, title, author, update, run
  f = File.open(filename,"w")
  f.puts "title: #{title}"
  f.puts "author: #{author}"
  f.puts "last_updated: #{update}"
  f.puts "last_run: #{run}"
  f.close
end

def fetch_texts work_directory, text_ncode, n_start, n_end

  text_ncode_url = "#{TEXT_BASE_URL}#{text_ncode}/"

  (n_start .. n_end).each do |n|
    text_url_parameter = "?no=#{n}&hankaku=0&code=utf-8&kaigyo=CRLF" 
    text_url = "#{text_ncode_url}/#{text_url_parameter}"
    filename = "#{work_directory}/#{n}.txt"
    puts "fetch #{n}/#{n_end}: #{text_url}"
    retryable(:tries => N_RETRY, :on => (OpenURI::HTTPError||SocketError), :wait => FETCH_WAIT) do
      fetch_url text_url, filename
    end
    sleep FETCH_WAIT
  end

end

########################
# Main
########################

page_url = nil
yomou_code = nil

arg = ARGV.shift
if /^#{YOMOU_BASE_URL}([^\/]+?)\// =~ arg
  url = arg.to_s
  yomou_code = $1.to_s
elsif /^n[a-z0-9]+?/ =~ arg # e.g. n4202cb
  yomou_code = arg
  url = YOMOU_BASE_URL + yomou_code + '/'
else
  puts "cannot parse args."
  exit
end

page = Nokogiri::HTML(open(url))

title, author = get_title_author(page)
last_update = get_last_update(page)
puts "Checking #{title} [#{author}] '#{yomou_code}' (last update: #{last_update})"
text_ncode = get_text_ncode(page)
unless text_ncode
  puts "cannot get ncode for #{arg} (#{title}, #{author}). exit."
  exit
end

#book_directory = "./work/#{title} [#{author}]"
book_directory = "./work/#{yomou_code}"
work_directory = "#{book_directory}/work/"
unless File.directory? work_directory
  FileUtils.mkdir_p work_directory
end
info_filename = "#{book_directory}/info.txt"
update_infofile(info_filename, title, author, last_update, Time.now.to_s)

latest_number = get_latest_article_number page, yomou_code
latest_file_number = get_latest_file_number work_directory
puts "latest article #{latest_number}, exists file #{latest_file_number}"
fetch_texts(work_directory, text_ncode, latest_file_number+1, latest_number)

