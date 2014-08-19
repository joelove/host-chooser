class Hostsfile
  FILE_LOCATION = '/etc/hosts'

  def initialize(hostdata, current, lines)
    @hostdata = hostdata
    @current = current
    @lines = lines
  end

  def update_hosts
    build_hosts
    write_hosts
  end

  private
  def read(filename)
    parse_file read_file(filename)
  end

  def build_hosts
    @hostdata.each do |line|
      @lines.push build_line(line)
    end
  end

  def write_hosts
    write_file @lines, FILE_LOCATION
  end

  def build_line(line)
    new_ip = line[:ip].to_s
    is_cur = new_ip == @current
    prefix = ''
    suffix = "### #{line[:desc]} ###\n"
    
    is_cur and prefix += '# '

    line_str = ''
    line_str += "#{prefix}#{new_ip.ljust(17)}www.which.co.uk        #{suffix}"
    line_str += "#{prefix}#{new_ip.ljust(17)}www.staticwhich.co.uk  #{suffix}"
  end

  def read_file(filename)
    lines = []
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