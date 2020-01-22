#!/usr/bin/ruby
#
#

require 'fileutils'
require 'shellwords'
require 'optparse'

YOMOU = 'yomou.rb'
KAKUYOMU = 'kakuyomu.rb'
MERGER = 'yomou_merger.rb'
BOOKLIST = 'booklist.txt'
BOOKDIR  = 'books'
UPDATEDIR = 'updates'

def get_code url
  code = nil
  if /syosetu\.com/ =~ url && /^https?:\/\/ncode\.syosetu\.com\/([^\/]+)\/?/ =~ url
    code = $1.to_s
  elsif /kakuyomu\.jp/ =~ url && /^https:\/\/kakuyomu\.jp\/works\/(\d+)\/?/ =~ url
    code = $1.to_s
  end
  code
end

options = {}
OptionParser.new do |op|
  op.banner = "Usage: yomou_batch.rb [options]"
  op.on("-v", "--verbose", "verbose output") do |v|
    options[:verbose] = v
  end
  op.on("-s NDAYS", "--skip=NDAYS", "skip checking site previous update was NDAYS before") do |o|
    options[:nskip] = o
  end
end.parse!

booklist = BOOKLIST 

codeflag = {}

puts "Fetch and build books start ===== #{Time.now}"
File.open(booklist).each do |l|
  url, flag, title = l.split(/ +/, 3)
  flag = (flag.to_i == 1 ? true : false)
  next unless /^http/ =~ url
  code = get_code url
  if /syosetu\.com/ =~ url 
    opts = options[:nskip] ? "-s #{options[:nskip]}" : ""
    system "ruby #{YOMOU} #{opts} #{url}"
  elsif /kakuyomu\.jp/ =~ url
    system "ruby #{KAKUYOMU} #{url}"
  else
    next
  end

  d = "work/#{code}"
  infofile = "#{d}/info.txt"
  info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }] if File.exists? infofile
  if info.empty?
    puts "no info recorded. aborting."
    next
  end
  unless info['new_stories'].to_i > 0
    puts "no new stories updated." if options[:verbose]
    sleep 3
    next
  end

  system "ruby #{MERGER} #{Shellwords.escape d}"
  bookname = "#{info['title']}\ \[#{info['author']}\].txt"

  if ! File.exist?("#{BOOKDIR}/#{bookname}") || 
      (File.exist?("#{d}/#{bookname}") && 
       File.new("#{d}/#{bookname}").mtime > File.new("#{BOOKDIR}/#{bookname}").mtime)
#       File.new("#{d}/#{bookname}").size > File.new("#{BOOKDIR}/#{bookname}").size)
    puts "Updated: #{bookname}" if options[:verbose]
    FileUtils.cp "#{d}/#{bookname}", BOOKDIR
    if flag
      FileUtils.mkdir UPDATEDIR unless Dir.exists? UPDATEDIR
      puts "Copied to updates: #{bookname}" if options[:verbose]
      FileUtils.cp "#{d}/#{bookname}", UPDATEDIR
    end
  end
  sleep 10
end
puts "Fetch and build books end   ===== #{Time.now}"

