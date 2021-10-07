#!/usr/bin/ruby
# coding: utf-8

require 'time'
require 'fileutils'

MAX_FILENAME_LENGTH=84

bookdir = ARGV.shift
unless File.directory? bookdir
  puts "no such directory: #{bookdir}"
  exit
end

is_escape_ruby = false
is_book_title_canonical = true

infofile = "#{bookdir}/info.txt"
workdir = "#{bookdir}/work"

info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }]

unless info['title'] && info['author']
  puts "no title or author found."
  exit
end

booktitle = info['title'].gsub(/\//, '／')
author = info['author']
if is_book_title_canonical
  booktitle.gsub!(/[（|【|『|＜].*?[章|完結|書籍|コミ|アニメ|発売].*?[）|】|』|＞]/, '')
  booktitle.gsub!(/^ +/,'')
  author = author.gsub(/\\(.+?\\)/, '').gsub(/（.+?）/, '')
end
bookfilename = "#{booktitle}\ \[#{author}\].txt"
# avoid filename is too long for POSIX system (255byte ~ 86 UTF-8 chars)
if bookfilename.length > MAX_FILENAME_LENGTH
  m = MAX_FILENAME_LENGTH - author.length - 8 # space, [] and '.txt'
  b = booktitle.slice(0..m)
  bookfilename = "#{b}..\ \[#{author}\].txt"
end

bookfile = "#{bookdir}/#{bookfilename}"

puts "merging files into #{bookfile}"
count_file = 0
line = 0
File.open(bookfile, 'w') do |book| 
  book.puts "#{info['title']} [#{author}]"
  book.puts 
  Dir.open(workdir).grep(/^\d+?\.txt/).sort{|a,b| a.gsub(/\.txt/,'').to_i <=> b.gsub(/\.txt/,'').to_i }.each do |file|
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

