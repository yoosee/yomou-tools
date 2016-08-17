#!/usr/bin/ruby
#
#

require 'fileutils'
require 'shellwords'

YOMOU = 'yomou.rb'
MARGE = 'yomou_merger.rb'
BOOKLIST = 'booklist.txt'
BOOKDIR  = 'books/'

puts "Fetching books start ===== #{Time.now}"
File.open(BOOKLIST).each do |l|
  url, title = l.split(/ +/, 2)
  next unless /^http/ =~ url
  system "ruby #{YOMOU} #{url}"
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
    FileUtils.mv "#{d}/#{bookname}", BOOKDIR
  end
end
puts "Building books end ===== #{Time.now}"
