require 'optparse'
require 'open-uri'
require 'nokogiri'
require 'pp'
require 'yaml'
require 'xpath'

$options = OpenStruct.new;

def read_config
  YAML::load_file "config.yml"
end

def parse_args
  $options.environment = nil
  $options.list = false
  OptionParser.new do |option|
    option.on('-l') { |b| $options[:list] = true }
    option.on('-h') { puts option; exit }
    option.parse!
  end
  $options
end

def string_compare(str1, str2)
  if (!str1 || !str2)
    return 0.to_f
  else
    str1, str2 = str1.dup.downcase, str2.dup.downcase
  end
  pairs1 = (0..str1.length-2).collect {|i| str1[i,2]}.reject {
    |pair| pair.include? " "}
  pairs2 = (0..str2.length-2).collect {|i| str2[i,2]}.reject {
    |pair| pair.include? " "}
  union = pairs1.size + pairs2.size 
  intersection = 0 
  pairs1.each do |p1| 
    0.upto(pairs2.size-1) do |i| 
      if p1 == pairs2[i] 
        intersection += 1 
        pairs2.slice!(i) 
        break 
      end 
    end 
  end 
  (2.0 * intersection) / union
end

class String
  def colorize(color_code); "\e[#{color_code}m#{self}\e[0m" end
  def black;          colorize(30) end
  def red;            colorize(31) end
  def green;          colorize(31) end
  def brown;          colorize(33) end
  def blue;           colorize(34) end
  def magenta;        colorize(35) end
  def cyan;           colorize(36) end
  def gray;           colorize(37) end
  def bg_black;       colorize(40) end
  def bg_red;         colorize(41) end
  def bg_green;       colorize(42) end
  def bg_brown;       colorize(43) end
  def bg_blue;        colorize(44) end
  def bg_magenta;     colorize(45) end
  def bg_cyan;        colorize(46) end
  def bg_gray;        colorize(47) end
  def bold;           colorize(1)  end
  def reverse_color;  colorize(7)  end
end

class Hostdata
  @@hostdata_local = File.dirname(__FILE__) + '/data/hostdata.yml'
  @@hostdata_source = 'http://lmrwikiw1.which.co.uk/WikiWhich/Java_Development/EEnvironments'

  def get
    begin
      @@hostdata_raw = open(@@hostdata_source).read
      @@hostdata_html = Nokogiri::HTML(@@hostdata_raw)
      @@hostdata_html.encoding = 'utf-8'
      @@hostdata = parse @@hostdata_html
      write @@hostdata
      @@hostdata
    rescue Exception=>e
      read
    end
  end

  def read
    YAML::load_file @@hostdata_local
  end

  def write(details)
    File.open(@@hostdata_local, "w") do |file|
      file.write details.to_yaml
    end
  end

  def parse(html)
    @@rows = html.xpath('//tr')
    @@details = @@rows.collect do |row|
      detail = {}
      [
        [:desc, 'td[1]/text()'],
        [:name, 'td[2]/text()'],
        [:ip,   'td[3]/text()'],
      ].each do |name, xpath|
        detail[name] = row.at_xpath(xpath).to_s.strip
      end
      detail
    end
    lookup @@details
  end

  def lookup(hostdata)
    hostdata
    # Socket.do_not_reverse_lookup = false
    # hostdata.each do |detail|
    #   puts details.to_s
    #   addrinfo = Socket.getaddrinfo(detail[:ip], nil)
    #   hostname = addrinfo[0][2]
    #   case
    #   when hostname == detail[:ip], hostname.start_with?('www')
    #     hostname = nil
    #   else
    #     hostname = hostname.split('.')[0]
    #   end
    #   detail.merge!(:hostname => hostname);
    # end
  end
end

class Hostsfile
  def read(filename)
    parse_file read_file(filename)
  end

  def build_lines(hostdata, current, lines)
    lines.push("\n")
    hostdata.each do |item|
      is_cur = item[:ip].to_s == current
      ip = item[:ip].ljust(17)
      prefix = is_cur ? '' : '# '
      suffix = "### #{item[:desc]} ###\n"
      line_str = ''
      line_str = line_str + "#{prefix}#{ip}www.which.co.uk        #{suffix}"
      line_str = line_str + "#{prefix}#{ip}www.staticwhich.co.uk  #{suffix}"
      lines.push(line_str)
    end
    lines
  end

  def read_file(filename)
    lines = [];
    open(filename) do |line|
      while data = line.gets
        lines.push(data)
      end
    end
    lines
  end

  def write_file(lines, filename)
    target = File.open(filename, 'w')
    target.truncate(target.size)
    lines.each do |line|
      target.write(line)
    end
    target.close()
  end

  def parse_file(lines)
    output = []
    main_regex = /###.+?###/
    cur_regex = /^[^#].+?###.+?###/
    ip_regex = /((?:[0-9]{1,3}\.){3}[0-9]{1,3})/
    lines.each do |line|
      if cur_regex.match(line) 
        current = ip_regex.match(line)
      elsif !main_regex.match(line) && line.chomp != ''
        output.push(line)
      end
    end
    output
  end
end

class Environment
  def switch(hostdata, env_data, lines, filename)
    if (!env_data)
      return
    end
    hostsfile = Hostsfile.new
    file_contents = hostsfile.build_lines(hostdata, env_data[:ip], lines)
    hostsfile.write_file(file_contents, filename)

    env = match(@current, hostdata);
    output = "Switched to #{env_data[:name]} (#{env_data[:desc]})"
    if $options[:list]
      output = output.center(61).green.bold.reverse_color
    end
    puts output
  end

  def match(input_str, hostdata)
    @list = []
    hostdata.each_with_index do |item, index|
      item.each do |key, value|
        @list.push(value)
      end
    end
    match = @list.sort_by{|ele|string_compare(input_str,ele)}.last
    find_environment(match, hostdata)
  end

  def find_environment(input_str, hostdata)
    hostdata.each_with_index do |item, index|
      item.each do |key, value|
        if input_str.to_s.downcase == value.to_s.downcase
          return hostdata[index]
        end
      end
    end
    puts "Failed to match: '#{input_str}'"
    return false
  end

  def print_current(lines, hostdata)
    cur_regex = /^[^#].+?###\s.+?###/
    ip_regex = /((?:[0-9]{1,3}\.){3}[0-9]{1,3})/
    lines.each do |line|
      if cur_regex.match(line) 
        @current = ip_regex.match(line)
        break
      end
    end
    env = find_environment(@current, hostdata);
    output = "Currently set to #{env[:name]} (#{env[:desc]})"
    if $options[:list]
      output = output.center(61).blue.bold.reverse_color
    end
    puts output
  end

  def print_list(hostdata)
    list_str = ''
    length_data = {}
    hostdata.each do |item|
      item.each do |key, value|
        if !length_data.has_key?(key)
          length_data[key] = 0;
        end
        if value.to_s.length > 16
          length_data[key] = 16
        elsif value.to_s.length > length_data[key]
          length_data[key] = value.to_s.length
        end
      end 
    end
    toggle = true
    title = " Enviroment Name".ljust(32) + "IP Address".ljust(17) + "Hostname"
    puts title.ljust(61).bold.reverse_color
    hostdata.each do |item|
      namelen = length_data[:name] + length_data[:desc];
      line = " #{item[:name]} (#{item[:desc]})".slice(0, 30).ljust(namelen)
      line = line + item[:ip].ljust(17)
      if item[:hostname]
        line = line + item[:hostname].ljust(12)
      else
        line = line + '            '
      end
      toggle = !toggle
      if (toggle)
        line = line.bold
      end
      puts line
    end
  end
end

# Start exec

parse_args
server = ARGV[0]
filename = "/etc/hosts"

hostdata = Hostdata.new.get
hostsfile = Hostsfile.new
environment = Environment.new

lines = hostsfile.read(filename)

if $options[:list]
  environment.print_list hostdata
end

if server
  env_data = environment.match(server, hostdata)
  environment.switch(hostdata, env_data, lines, filename)
else
  environment.print_current(hostsfile.read_file(filename), hostdata)
end