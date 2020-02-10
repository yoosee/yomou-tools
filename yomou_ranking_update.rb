#!/usr/bin/ruby
# coding: utf-8
#
# fetch multiple entries in Yomou Ranking page.
#

require 'rubygems'
require 'time'
require 'date'
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'optparse'
require 'shellwords'

YOMOU = 'yomou.rb'
KAKUYOMU = 'kakuyomu.rb'
MERGER = 'yomou_merger.rb'
BOOKLIST = 'booklist.txt'
BOOKDIR  = 'books'
UPDATEDIR = 'updates'

MAX_TITLES_RANK = 100

YOMOU_BASE_URL = 'https://ncode.syosetu.com/'
YOMOU_BASE_DOMAIN = 'ncode.syosetu.com'
YOMOU_RANK_DOMAIN = 'yomou.syosetu.com'

class YomouItem
  attr_accessor :url, :title
  def initialize url, title
    @url = url
    @title = title
  end
end

def get_code url
  code = nil
  if /syosetu\.com/ =~ url && /^#{YOMOU_BASE_URL}([^\/]+)\/?/ =~ url
    code = $1.to_s
#  elsif /kakuyomu\.jp/ =~ url && /^https:\/\/kakuyomu\.jp\/works\/(\d+)\/?/ =~ url
#    code = $1.to_s
  end
  code
end

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
options[:n_fetch] = MAX_TITLES_RANK

OptionParser.new do |opts|
  opts.banner = "Usage: yomou.rb [options] URL_RANKING_PAGE"
  opts.on("-v", "--verbose", "Run verbosely") do |o|
    options[:verbose] = o
  end
  opts.on("-n N", "--number-fetch=N", "Number of items to be fetched in the Ranking.") do |o|
    options[:n_fetch] = o
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

#testfile = "ranktest.html"

begin 
  page = Nokogiri::HTML(open(rankpage_url))
#  page = Nokogiri::HTML(open(testfile))
rescue OpenURI::HTTPError
  puts "[Error] #{$!} on fetching #{yomou_code}"
  exit
end

ranklist = list_ranking page

n = 0
ranklist.each do |url|
begin
  code = get_code url
  dir = "work/#{code}"
  opts = ""
  system "ruby #{YOMOU} #{opts} #{url}"
  system "ruby #{MERGER} #{Shellwords.escape dir}"

  infofile = "#{dir}/info.txt"
  info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }] if File.exists? infofile
  bookname = "#{info['title']}\ \[#{info['author']}\].txt"
  
  if ! File.exist?("#{BOOKDIR}/#{bookname}") ||
      (File.exist?("#{dir}/#{bookname}") &&
       File.new("#{dir}/#{bookname}").mtime > File.new("#{BOOKDIR}/#{bookname}").mtime)
    puts "Updated: #{bookname}" if options[:verbose]
    FileUtils.cp "#{dir}/#{bookname}", BOOKDIR

    FileUtils.mkdir UPDATEDIR unless Dir.exists? UPDATEDIR
    puts "Copied to updates: #{bookname}" if options[:verbose]
    FileUtils.cp "#{dir}/#{bookname}", UPDATEDIR
  end

  n += 1
  break if n > options[:n_fetch]
rescue
  next
end
end

