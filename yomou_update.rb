#!/usr/bin/ruby
#
#

require 'fileutils'
require 'shellwords'
require 'optparse'

YOMOU = 'yomou.rb'
KAKUYOMU = 'kakuyomu.rb'
MARGE = 'yomou_merger.rb'
BOOKLIST = 'booklist.txt'
BOOKDIR  = 'books'
UPDATEDIR = 'updates'

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

codeflag = []

puts "Fetching books start ===== #{Time.now}"
File.open(booklist).each do |l|
  url, flag, title = l.split(/ +/, 3)
  flag = (flag.to_i == 1 ? true : false)
  next unless /^http/ =~ url
  code = get_code url
  codeflag[code] = flag
  if /syosetu\.com/ =~ url 
    opts = options[:nskip] ? "-s #{options[:nskip]}" : ""
    system "ruby #{YOMOU} #{opts} #{url}"
  elsif /kakuyomu\.jp/ =~ url
    system "ruby #{KAKUYOMU} #{url}"
  end
  sleep 20
end
puts "Fetching books end   ===== #{Time.now}"

puts "Building books start ===== #{Time.now}"
Dir.open("./work").each do |n|
  d = "work/#{n}"
  next if ! File.directory? d or /\/\./ =~ d
  system "ruby #{MARGE} #{Shellwords.escape d}"
  infofile = "#{d}/info.txt"
  info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }]
  bookname = "#{info['title']}\ \[#{info['author']}\].txt"
  if ! File.exist?("#{BOOKDIR}/#{bookname}") || 
      (File.exist?("#{d}/#{bookname}") && 
       File.new("#{d}/#{bookname}").size > File.new("#{BOOKDIR}/#{bookname}").size)
    puts "Updated: #{bookname}" 
    FileUtils.cp "#{d}/#{bookname}", BOOKDIR
    if codeflag[n]
      FileUtils.cp "#{d}/#{bookname}", UPDATEDIR
    end
  end
end
puts "Building books end ===== #{Time.now}"

def get_code url
  code = nil
  if /syosetu\.com/ =~ url && /^https?:\/\/ncode\.syosetu\.com\/([^\/]+)\/?/ =~ url
    code = $1.to_s
  elsif /kakuyomu\.jp/ =~ url && /^https:\/\/kakuyomu\.jp\/works\/(\d+)\/?/ =~ url
    code = $1.to_s
  end
  code
end

