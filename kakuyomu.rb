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

# e.g. https://kakuyomu.jp/works/1177354054882961557
KAKUYOMU_BASE_URL = 'https://kakuyomu.jp'

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
  # <h1 id="workTitle"><a href="/works/1177354054882961557">魔法使いで引きこもり？－モフモフ以外とも心を通わせよう物語－</a></h1>
  title = page.css('h1#workTitle').children.first.inner_html
  # <span id="workAuthor-activityName"><a href="/users/m_kotoriya">小鳥屋エム</a></span>
  author = page.css('span#workAuthor-activityName').children.first.inner_html
  return title, author
end

def get_latest_article_number page, yomou_code
  latest_number = 0 
  page.css('li.widget-toc-episode > a').each do |subtitle_url| 
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
  # <p class="widget-toc-date"><time datetime="2017-07-18T03:53:14Z">2017年7月18日 12:53</time> 更新</p>
  page.xpath("//p[@class='widget-toc-date']/time").attribute('datetime')
end

def update_infofile filename, title, author, update, run
  f = File.open(filename,"w")
  f.puts "title: #{title}"
  f.puts "author: #{author}"
  f.puts "last_updated: #{update}"
  f.puts "last_run: #{run}"
  f.close
end

def fetch_text work_file, url

#     <div id="contentMain-inner">
#      <header id="contentMain-header">
#        <p class="chapterTitle level1"><span>第一章　王都ロワル</span></p>
#        <p class="widget-episodeTitle">011　貨幣価値と王都</p>
#      </header>
#      <div class="widget-episode js-episode-body-container">
#         <div class="widget-episode-inner">
#            <div class="widget-episodeBody js-episode-body" data-viewer-history-path="/works/1177354054882961557/episodes/1177354054882962488/history"><p id="p1" class="blank"><br /><br /><br /></p>
#<p id="p2">　予定通りにシアナ街を出て、王都に向かう。あとは小さな村々を通り過ぎればいいだけで、旅ももう終わりだ。</p>
#<p id="p3">　隠蔽魔法は相変わらず完成していないが、スタン爺さんからはいろいろ教わることができて覚えたことも多い。</p>
#....

  page = Nokogiri::HTML(open(url))
  episode_title = page.xpath('//p[@class="widget-episodeTitle"]').text
  ep_no = url.match(/episodes\/(\d+)/)
  content = episode_title + "\n"
  page.xpath('//div[@class="widget-episodeBody js-episode-body"]/p').each do |p|
    content << p.text.gsub(/<br[^>]*?>/, "\n") << "\n"
  end
  File.write work_file, content
end

def get_num_files dir
  n=0
  Dir.open(dir).each do |f|
    n+=1 if /\.txt/ =~ f
  end
  n
end

def get_num_episodes page
  n = 0
  page.xpath("//li[@class='widget-toc-episode']/a").each do |e|
    n+=1
  end
  n
end

def fetch_texts work_directory, page, last_ep_no

# <li class="widget-toc-episode">
#   <a href="/works/1177354054882961557/episodes/1177354054883515324">
#     <span class="widget-toc-episode-titleLabel">480　現地へ移動、飛竜と希少獣のレース</span>
#     <time class="widget-toc-episode-datePublished" datetime="2017-07-03T22:00:24Z">2017年7月4日</time>
#   </a>
# </li>

  num_episodes = get_num_episodes page
  num_files = get_num_files work_directory
  n = num_files
  page.xpath("//li[@class='widget-toc-episode']/a").each do |e|
    href = e.attribute('href')
    if /episodes\/(\d+)/ =~ href
      ep_no = $1
      url = "#{KAKUYOMU_BASE_URL}#{href}"
    end
    next if ep_no.to_i <= last_ep_no
    n+= 1
    ep_filename = "#{work_directory}/#{ep_no}.txt"
    ep_title = e.xpath('span[@class="widget-toc-episode-titleLabel"]').text
    puts "fetching #{ep_no} #{ep_title} (#{n}/#{num_episodes})"
    fetch_text ep_filename, url
    sleep FETCH_WAIT
  end
end

########################
# Main
########################

page_url = nil
code = nil

arg = ARGV.shift
if /^#{KAKUYOMU_BASE_URL}\/works\/(\d+)\/?/ =~ arg
  url = arg.to_s
  code = $1.to_s
elsif /^\d+$/ =~ arg # e.g. 3874013709
  code = arg
  url = KAKUYOMU_URL + code + '/'
else
  puts "[Error] cannot parse args."
  exit
end

begin 
  page = Nokogiri::HTML(open(url))
rescue OpenURI::HTTPError
  puts "[Error] #{$!} on fetching #{code}"
  exit
end

title, author = get_title_author(page)
last_update = get_last_update(page)
puts "Checking #{title} [#{author}] '#{code}' (last update: #{last_update})"

book_directory = "work/#{code}"
work_directory = "#{book_directory}/work"
FileUtils.mkdir_p work_directory unless File.directory? work_directory
latest_file_number = get_latest_file_number work_directory
fetch_texts(work_directory, page, latest_file_number)

info_filename = "#{book_directory}/info.txt"
update_infofile(info_filename, title, author, last_update, Time.now.to_s)

