#!/usr/bin/ruby

nv_table = proc{
  res = {}
  open(File::join(File::dirname(__FILE__), 'nv_complete.txt')).each{|line|
    next if line =~ /^\s*(?:$|#)/ # accept empty line
    next unless line.chomp =~ /(\d+)\^(\"[^\"]+\")\^(\"[^\"]+\")/
    res[$1.to_i] = [$2, $3]
  }
  res
}.call

open(ARGV.shift).each{|line|
  next if line =~ /^\s*(?:$|#)/ # accept empty line
  type, location, *other = line.chomp.split(',')
  next if type.to_i != 1
  idx = location.to_i
  puts ([idx] + (nv_table[idx] || ([nil] * 2)) + other).join(',')
}
