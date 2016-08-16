#!/usr/bin/ruby
# coding: utf-8


bookdir = ARGV.shift
unless File.directory? bookdir
  puts "no such directory: #{bookdir}"
  exit
end

is_escape_ruby = false

infofile = "#{bookdir}/info.txt"
workdir = "#{bookdir}/work/"

info = Hash[ File.open(infofile).each_line.map {|l| l.chomp.split(":\s", 2) }]
p info

unless info['title'] && info['author']
  puts "no title or author found."
  exit
end
bookfile = "#{bookdir}/#{info['title']}\ \[#{info['author']}\].txt"

puts "merging file into #{bookfile}"
count_file = 0
File.open(bookfile, 'w') do |book| 
  book.puts "#{info['title']} [#{info['author']}]"
  book.puts 
  Dir.open(workdir).grep(/\d+?\.txt/).sort{|a,b| a.gsub(/\.txt/,'').to_i <=> b.gsub(/\.txt/,'').to_i }.each do |file|
    File.open("#{workdir}/#{file}") do |f|
      f.each do |i|
        i = i.gsub(/《/,'<<').gsub(/》/,'>>') if is_escape_ruby
        book.write i.gsub(/&quot;/,'"').gsub(/&lt;/,'<').gsub(/&gt;/,'>').gsub(/&amp;/,'&')
      end
      book.puts "\n\n" 
    end
    count_file += 1
  end
end

puts "#{count_file} files merged."

