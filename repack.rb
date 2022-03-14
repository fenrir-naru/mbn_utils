#!/usr/bin/ruby

ELF32_HEADER = [
  [:magic, "C16", "\x7FELF".unpack("C*") + [1,1]], # 0x00-

  [:type, "v", 2], # 0x10-
  [:machine, "v", 0], # 0x12-
  [:version, "V", 1], # 0x14-

  [:entry_point_offset, "V"], # 0x18-
  [:program_header_offset, "V"], # 0x1C-
  [:section_header_offset, "V"], # 0x20-

  [:flags, "V"], # 0x24-
  [:header_size, "v", 52], # 0x28-
  [:program_header_size, "v", 32], # 0x2A-
  [:program_headers, "v", 3], # 0x2C-
  [:section_header_size, "v"], # 0x2E-
  [:section_headers, "v"], # 0x30-
  [:section_header_index, "v"], # 0x32-
]

ELF32_PROGRAM_HEADER = [
  [:type, "V"],
  [:offset, "V"],
  [:virtual_address, "V"],
  [:physical_address, "V"],
  [:file_bytes, "V"],
  [:mem_bytes, "V"],
  [:flags, "V"],
  [:align, "V"],
]

MCFG_HEADER = [
  [:magic, "C4", "MCFG".unpack("C*")], # 0x00-
  [:format_type, "v"], # 0x04-
  [:configuration_type, "v"], # 0x06-
  [:items, "V"], # 0x08-
  [:carrier_index, "v"], # 0x0C-
  [:reserved, "v"], # 0x0E-
  [:version_id, "v", 4995], # 0x10-
  [:version_size, "v", 4], # 0x12-
  [:version, "V"], # 0x14-
]

ITEM_HEADER = [
  [:length, "V"],
  [:type, "C"],
  [:attributes, "C"],
  [:reserved, "v"],
]

[MCFG_HEADER, ITEM_HEADER].each{|table|
  res = table.inject(0){|result, item|
    result + ([0] * 16).pack(item[1]).length
  }
  table.define_singleton_method(:min_bytes){res}
}

def parse(table, input)
  require 'stringio'
  io = case input
  when IO, StringIO
    input
  when String
    StringIO::new(input)
  else
    raise
  end
  Hash[*(table.collect{|k, fmt, expected|
    len = ([0] * 0x400).pack(fmt).size
    str = io.read(len)
    data = str.unpack(fmt)
    data = data[0] if data.size == 1
    case expected
    when Array
      raise unless data.slice(0, expected.length) == expected
    when nil
    else
      raise unless data == expected
    end
    [k, data]
  }.flatten(1))]
end

def deparse(table, hash)
  table.collect{|k, fmt|
    [hash[k]].flatten.pack(fmt)
  }.join
end

fname = ARGV.shift

# Parse phase
buf = open(fname, 'rb').read
$stderr.puts "Input: #{fname} (size: #{buf.size})"
elf_header = parse(ELF32_HEADER, buf)
$stderr.puts "ELF: #{elf_header}"
program_headers = elf_header[:program_headers].times.collect{|i|
  offset = elf_header[:program_header_offset] \
      + elf_header[:program_header_size] * i
  parse(ELF32_PROGRAM_HEADER, buf[offset..-1])
}
mcfg_seg = proc{|seg|
  $stderr.puts "MCFG_SEG: #{seg}"
  require 'stringio'
  StringIO::new(buf[seg[:offset], seg[:file_bytes]])
}.call(program_headers[2])
mcfg_header = parse(MCFG_HEADER, mcfg_seg)
$stderr.puts "MCFG: #{mcfg_header}"

items = (mcfg_header[:items] - 1).times.collect{|i|
  header = parse(ITEM_HEADER, mcfg_seg)
  prop, content = [nil, nil]
  case header[:type]
  when 1 # Nv
    prop = parse([
          [:id, "v"],
          [:length_1, "v"], # length + 1
          [:magic, "C"],
        ], mcfg_seg)
    #$stderr.puts "NV(%05d, %d)"%[prop[:id], prop[:length_1] - 1]
    content = mcfg_seg.read(prop[:length_1] - 1)
  when 2, 4 # NvFile(2), File(4)
    is_nv = (header[:type] == 2)
    prop = parse([
          [:magic, "v", 1],
          [:fname_length, "v"], # with end '\0'
        ], mcfg_seg)
    prop[:fname] = mcfg_seg.read(prop[:fname_length])[0..-2]
    prop.merge!(parse([
          [:size_magic, "v", 2],
          [:length_1, "v"], # length + 1
          [:data_magic, "C"],
        ], mcfg_seg))
    #$stderr.puts "#{is_nv ? "ItemFile" : "File"}(%s, %d)"%[prop[:fname], prop[:length_1] - 1]
    content = mcfg_seg.read(prop[:length_1] - 1)
  else
    raise "Unknown item: #{header}"
  end
  [header, prop, content]
}
trailer = parse(ITEM_HEADER, mcfg_seg)
raise unless trailer[:type] == 10
trailer.merge!(parse([
      [:magic2, "v", 0xA1],
      [:data_length, "v"],
    ], mcfg_seg))
trailer.merge!(parse([
      [:data, 
        "C#{[trailer[:data_length], trailer[:length] - 12].max}", # TODO unknown tailer spec
        "MCFG_TRL".unpack("C8")],
    ], mcfg_seg))
#$stderr.puts "trailer: #{trailer}"

# Extraction phase
dir_extract = "#{fname}.extracted"
fname_list = File::join(dir_extract, "items.txt")
proc{
  require 'fileutils'
  FileUtils.mkdir_p(dir_extract) unless Dir::exist?(dir_extract)
  files = {}
  open(fname_list, 'w'){|io|
    items.each{|header, prop, content|
      case header[:type]
      when 1 # Nv
        io.puts([header[:type], prop[:id],
            prop[:magic], 
            content.unpack("C*").collect{|v| "%02X"%[v]}.join(' ')].join(','))
      when 2, 4 # NvFile(2), File(4)
        files[prop[:fname]] ||= 0
        io.puts([header[:type], prop[:fname],
            prop[:magic], prop[:size_magic], prop[:data_magic],
            content.size, files[prop[:fname]]].join(','))
        fname_dst = File::join(dir_extract, prop[:fname])
        FileUtils.mkdir_p(File::dirname(fname_dst))
        File::open(fname_dst, 'ab'){|io2| io2 << content}
        files[prop[:fname]] += content.size
      end
    }
  } unless File::exist?(fname_list)
}.call

# Combine phase
items_new = open(fname_list, 'r').collect.with_index{|line, i|
  next nil if line =~ /^\s*(?:$|#)/ # accept empty line
  type, location, *other = line.chomp.split(',')
  type = Integer(type)
  prop, content = case type
  when 1 # Nv
    content = other[1].split(/\s+/).collect{|str| str.to_i(16)}.pack("C*")
    prop = [Integer(location), content.length + 1, Integer(other[0])].pack("vvC")
    [prop, content]
  when 2, 4 # NvFile(2), File(4)
    len_content = Integer(other[3]) rescue nil # check dummy item entry
    src_offset = Integer(other[4])
    content = (0 == len_content) \
        ? "" \
        : open(File::join(dir_extract, location), 'rb').read[src_offset, len_content]
    prop = [
      Integer(other[0]), # magic
      location.length + 1, # fname_length
    ].pack("vv") + location + "\0" + [
      Integer(other[1]), # size_magic
      content.length + 1, # length_1
      Integer(other[2]), # data_magic
    ].pack("vvC")
    [prop, content]
  end
  #$stderr.puts items[i][0..1].inspect if ![80, 25].include?(items[i][0][:attributes]) #|| (items[i][0][:type] == 1)
  deparse(ITEM_HEADER, {
    :length => ITEM_HEADER.min_bytes + prop.length + content.length,
    :type => type,
    :attributes => proc{
      # monkey patch
      next 25 if (type == 2 && location == "/sd/rat_acq_order")
      next 80 if (content.length == 0)
      next 57 if (1 == type) && [10, 256, 441, 946, 2954].include?(Integer(location))
      25
    }.call,
    :reserved => 0,
  }) + prop + content
}.compact + [deparse(ITEM_HEADER + [
  [:magic2, "v"],
  [:data_length, "v"],
  [:data, "C*"],
], trailer)]

mcfg_seg_new = deparse(
    MCFG_HEADER, mcfg_header.merge({:items => items_new.length})) + items_new.join

proc{
  len_old = MCFG_HEADER.min_bytes \
      + items.collect.with_index.to_a.inject(0){|res, v|
        item_old, item_new = [v[0], items_new[v[1]]]
        len = item_old[0][:length]
        len2 = item_new ? item_new.length : nil
        if len != len2 then
          #$stderr.puts "different item size @ #{v[1]}:#{item_old}: old(#{len}) != new(#{len2})"
        end
        res + len
      } + trailer[:length]
  $stderr.puts "main segment size: #{len_old} => #{mcfg_seg_new.length}"
}.call
proc{|rem_bytes| # alignment
  next if rem_bytes == 0
  mcfg_seg_new += "\0" * (program_headers[2][:align] - rem_bytes)
}.call(mcfg_seg_new.length % program_headers[2][:align])

buf[program_headers[2][:offset], program_headers[2][:file_bytes]] \
    = mcfg_seg_new
program_headers[2][:file_bytes] = mcfg_seg_new.length
buf[
      elf_header[:program_header_offset] + elf_header[:program_header_size] * 2,
      elf_header[:program_header_size]] \
    = deparse(ELF32_PROGRAM_HEADER, program_headers[2])

fname_repacked = "#{fname}.repacked"
$stderr.puts "Rapacking: #{fname} => #{fname_repacked}"
open(fname_repacked, 'wb').write(buf)
