#!/usr/bin/ruby
# coding: utf-8

require 'time'
require 'fileutils'

bookdir = ARGV.shift
unless File.directory? bookdir
  puts "no such directory: #{bookdir}"
  exit
end

is_escape_ruby = false

infofile = "#{bookdir}/info.txt"
workdir = "#{bookdir}/work"

info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }]

unless info['title'] && info['author']
  puts "no title or author found."
  exit
end
bookfile = "#{bookdir}/#{info['title']}\ \[#{info['author']}\].txt"

puts "merging files into #{bookfile}"
count_file = 0
line = 0
File.open(bookfile, 'w') do |book| 
  book.puts "#{info['title']} [#{info['author']}]"
  book.puts 
  Dir.open(workdir).grep(/\d+?\.txt/).sort{|a,b| a.gsub(/\.txt/,'').to_i <=> b.gsub(/\.txt/,'').to_i }.each do |file|
    File.open("#{workdir}/#{file}") do |f|
      f.each do |i|
        i = i.gsub(/《/,'<<').gsub(/》/,'>>') if is_escape_ruby
        book.write i.gsub(/&quot;/,'"').gsub(/&lt;/,'<').gsub(/&gt;/,'>').gsub(/&amp;/,'&')
        line += 1
      end
      book.puts "\n\n" 
    end
    count_file += 1
  end
end

def format_num num
  num.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
end

lastupdated_time = Time.parse("#{info['last_updated']} +0900")
FileUtils.touch bookfile, :mtime => lastupdated_time

size = File.open(bookfile).size / 1024
puts "#{count_file} files merged. total #{format_num(line+2)} lines, #{format_num(size)} KB. updated #{lastupdated_time.to_s}"

