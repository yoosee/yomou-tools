#!/usr/bin/ruby
# coding: utf-8


bookdir = ARGV.shift
unless File.directory? bookdir
  puts "no such directory: #{bookdir}"
  exit
end

bookfile = "#{bookdir}/#{bookdir.gsub(/\//,'')}.txt"
workdir = "#{bookdir}/work/"

puts "merging file into #{bookfile}"

count_file = 0
File.open(bookfile, 'w') do |book| 
  book.puts bookdir
  book.puts 
  Dir.open(workdir).grep(/\d+?\.txt/).sort{|a,b| a.gsub(/\.txt/,'').to_i <=> b.gsub(/\.txt/,'').to_i }.each do |file|
    File.open("#{workdir}/#{file}") do |f|
      f.each do |i|
        book.write i.gsub(/&quot;/,'"').gsub(/《/,'<<').gsub(/》/,'>>').gsub(/&lt;/,'<').gsub(/&gt;/,'>').gsub(/&amp;/,'&')
      end
      book.puts "\n\n" 
    end
    count_file += 1
  end
end

puts "#{count_file} files merged."

