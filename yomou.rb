#!/usr/bin/ruby
# coding: utf-8
#
#

require 'rubygems'
require 'time'
require 'date'
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'optparse'

FETCH_WAIT = 15
N_RETRY = 4
RETRY_WAIT = 10
YOMOU_BASE_URL = 'https://ncode.syosetu.com/'
YOMOU_BASE_DOMAIN = 'ncode.syosetu.com'
TEXT_BASE_URL  = 'https://ncode.syosetu.com/txtdownload/dlstart/ncode/'
USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'

def fetch_url url, filename
  if File.exists? filename
    rotate_file filename
  end
  open(filename, 'w') do |file|
    open(url,
         "User-Agent" => USER_AGENT) do |data|
      file.write data.read
    end
  end
end

def rotate_file filename # shift file e.g. 10.txt => 10.1.txt, 10.1.txt => 10.2.txt
  f_base = filename.gsub(/\.txt/, '')
  n = 1
  f = "#{f_base}.#{n}.txt"
  while File.exists? f
    n += 1
    f = "#{f_base}.#{n}.txt"
  end
  for l in n..1 do
    if l == 1
      orig = filename
    else
      orig = "#{f_base}.#{l-1}.txt"
    end
    dest = "#{f_base}.#{l}.txt"
    puts "rotate file #{orig} to #{dest}"
    FileUtils.mv(orig, dest)
  end
end

def retryable(options = {}, &block)
  opts = { :tries => N_RETRY, :on => Exception, :wait => RETRY_WAIT}.merge(options)
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
  #
  # TXTダウンロードが表示されない場合の暫定解
  # https://syosetu.com/ihantsuhou/input/ncode/1329153/
  text_ncode = nil 
  page.css('div#novel_footer').first.css('li').each do |li| 
    href = li.css('a').first.attribute('href').value 
    if /txtdownload\/top\/ncode\/(\d+?)\// =~ href 
      text_ncode = $1
    elsif /input\/ncode\/(\d+?)\// =~ href 
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

def list_updated page, yomou_code, last_run
  updated = Array.new
  page.css('dl.novel_sublist2').each do |s|
    if !s.xpath('dt/span').empty? && /(\d{4}\/\d\d\/\d\d \d\d:\d\d)/ =~ s.xpath('dt/span').attribute('title').value
      t = Time.parse($1)
      next if t <= last_run
      if /\/#{yomou_code}\/(\d+?)\// =~ s.xpath('dd/a').attribute('href').value
        n = $1.to_i
        updated.push n
      end
    end
  end
  return updated
end

def update_infofile filename, title, author, update, run, new_stories
  f = File.open(filename,"w")
  f.puts "title: #{title}"
  f.puts "author: #{author}"
  f.puts "last_updated: #{update}"
  f.puts "last_run: #{run}"
  f.puts "new_stories: #{new_stories}"

  f.close
end

def read_infofile filename
  info = {}
  return info unless File.exists? filename
  File.open(filename) do |f|
    f.each do |l|
      k = l.split(":",2)
      info[k[0].strip] = k[1].strip
    end
  end
  return info
end

def fetch_text work_directory, text_ncode, n
  text_url_parameter = "?no=#{n}&hankaku=0&code=utf-8&kaigyo=CRLF" 
  text_url = "#{TEXT_BASE_URL}#{text_ncode}/#{text_url_parameter}"
  filename = "#{work_directory}/#{n}.txt"
  puts text_url
  retryable(:tries => N_RETRY, :on => (OpenURI::HTTPError||SocketError), :wait => FETCH_WAIT) do
    fetch_url text_url, filename
  end
end

def fetch_texts work_directory, text_ncode, n_start, n_end
  (n_start .. n_end).each do |n|
    print "fetch #{n}/#{n_end}: "
    fetch_text work_directory, text_ncode, n
    sleep FETCH_WAIT
  end

end

########################
# Main
########################

page_url = nil
yomou_code = nil

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: yomou.rb [options] URL_OR_CODE"
  opts.on("-v", "--verbose", "Run verbosely") do |o|
    options[:verbose] = o
  end
  opts.on("-s NDAYS", "--skip-old=NDAYS", "Skip executing the entry last-run update was NDAYS before.") do |o|
    options[:skip] = o
  end
  opts.on("-u", "--update-all-revised", "Fetch all updated content") do |o|
    options[:update] = o
  end
end.parse!

arg = ARGV.shift
if /^https?:\/\/#{YOMOU_BASE_DOMAIN}\/([^\/]+)\/?/ =~ arg
  url = arg.to_s
  yomou_code = $1.to_s
elsif /^n[a-z0-9]+?/ =~ arg # e.g. n4202cb
  yomou_code = arg
  url = YOMOU_BASE_URL + yomou_code + '/'
else
  puts "[Error] cannot parse args."
  exit
end

book_directory = "./work/#{yomou_code}"
work_directory = "#{book_directory}/work/"
unless File.directory? work_directory
  FileUtils.mkdir_p work_directory
end
info_filename = "#{book_directory}/info.txt"
info = read_infofile info_filename
if options[:skip]
  if info["last_updated"] && (Time.now - Time.parse(info["last_updated"]))/(60*60*24) > options[:skip].to_i
    puts "Last run informs last update was older than #{options[:skip]} days (#{info["last_updated"]}), skipping."
    exit
  end
end

begin 
  page = Nokogiri::HTML(open(url))
rescue OpenURI::HTTPError
  puts "[Error] #{$!} on fetching #{yomou_code}"
  exit
end

title, author = get_title_author(page)
last_update = get_last_update(page)
puts "Checking #{title} [#{author}] '#{yomou_code}' (last update: #{last_update})"
text_ncode = get_text_ncode(page)
unless text_ncode
  puts "cannot get ncode for #{arg} (#{title}, #{author}). exit."
  exit
end

latest_number = get_latest_article_number page, yomou_code
latest_file_number = get_latest_file_number work_directory
new_stories = latest_number - latest_file_number

info = read_infofile info_filename
last_run = info['last_run']
last_run = 0 if options[:update]

begin 
  list = list_updated page, yomou_code, Time.parse(last_run) 
  puts "Updating revised entries..." unless list.empty?
  list.each do |n|
    fetch_text work_directory, text_ncode, n
    sleep FETCH_WAIT
  end
rescue 
  puts "Update error: #{yomou_code}"
end

update_infofile(info_filename, title, author, last_update, Time.now.to_s, new_stories)
puts "Files: [#{latest_file_number}/#{latest_number}] (#{new_stories} new)"

fetch_texts(work_directory, text_ncode, latest_file_number+1, latest_number)

