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
YOMOU_RANK_DOMAIN = 'yomou.syosetu.com'
USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'

def list_ranking page
  rank = Array.new
  page.css('div.ranking_list').each do |s|
    if !s.css('div.rank_h/a').empty?
      url = s.xpath('div/a').attribute('href').value
      title = s.xpath('div/a').inner_html
      rank.push url
      puts "#{url} #{title}"
    end
  end
  return rank
end

########################
# Main
########################

rankpage_url = 'https://yomou.syosetu.com/rank/list/type/quarter_total/' # 四半期総合ランクをデフォルト

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
if /^https?:\/\/#{YOMOU_BASE_DOMAIN}\/[^\/]+\/?/ =~ arg
  rankpage_url = arg.to_s
else
end

testfile = "ranktest.html"

begin 
#  page = Nokogiri::HTML(open(rankpage_url))
  page = Nokogiri::HTML(open(testfile))
rescue OpenURI::HTTPError
  puts "[Error] #{$!} on fetching #{yomou_code}"
  exit
end

ranklist = list_ranking page

ranklist.each do |url|
end

