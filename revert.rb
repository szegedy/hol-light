ARGV.each do |fn|
  puts "mv #{fn} #{fn.gsub(/\.bak/,'')}"
end
