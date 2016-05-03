#!/usr/bin/ruby
#
#

require 'fileutils'
require 'shellwords'

YOMOU = 'yomou.rb'
MARGE = 'yomou_merger.rb'
BOOKLIST = 'booklist.txt'
BOOKDIR  = 'books/'

puts "Fetching books ===== #{Time.now}"
File.open(BOOKLIST).each do |l|
  url, title = l.split(/ +/, 2)
  next unless /^http/ =~ url
  system "ruby #{YOMOU} #{url}"
  sleep 30
end

puts "Building books ===== #{Time.now}"
Dir.open(".").each do |d|
  next if ! File.directory? d or /^\./ =~ d
  e = Shellwords.escape d
  system "ruby #{MARGE} #{e}"
  if ! File.exist?("#{BOOKDIR}/#{d}.txt") || 
    (File.exist?("#{d}/#{d}.txt") && File.exist?("#{BOOKDIR}/#{d}.txt") && 
     File.new("#{d}/#{d}.txt").size > File.new("#{BOOKDIR}/#{d}.txt").size)
    puts "Updated: #{d}" 
    FileUtils.mv "#{d}/#{d}.txt", BOOKDIR
  end
end

