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
BOOKDIR  = 'books/'

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

puts "Fetching books start ===== #{Time.now}"
File.open(booklist).each do |l|
  url, title = l.split(/ +/, 2)
  next unless /^http/ =~ url
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
  end
end
puts "Building books end ===== #{Time.now}"
