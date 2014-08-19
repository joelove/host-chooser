class Object
  def norm
    self.to_s.downcase
  end
end

class Environment
  def initialize(@hostdata, env_data, lines, filename)
    @hostdata = @hostdata
    @env_data = env_data
    @lines    = lines
    @filename = filename
  end

  def switch
    return unless env_data
    update_hosts
    notify_switched
  end

  def update_hosts
    hostsfile = Hostsfile.new(@hostdata, @env_data[:ip], @lines)
    hostsfile.update_hosts
  end

  def match(input_str)
    match = @hostdata.values.sort_by do |ele|
      string_compare(input_str, ele)
    end
    find_environment(match.last)
  end

  def find_environment(input_str)
    @hostdata.each_with_index do |item, index|
      match = item.detect |_, value| { input_str.norm == value.norm }
      return match if match
    end
    notify_failed_match input_str
  end

  def print_current(lines)
    env = find_environment(current_line)
    notify_current_env(env[:name], env[:desc])
  end

  def current_line
    cur_regex = /^[^#].+?###\s.+?###/
    ip_regex = /((?:[0-9]{1,3}\.){3}[0-9]{1,3})/

    @lines.each do |line|
      return ip_regex.match(line) if cur_regex.match(line) 
    end
  end

  def print_list
    tp @hostdata
  end

  def notify_switched
    puts "Switched to #{env_data[:name]} (#{env_data[:desc]})"
  end

  def notify_failed_match(input_str)
    puts "Failed to match: '#{input_str}'"
  end

  def notify_current_env(name, desc)
    puts "Currently set to #{name} (#{desc})"
  end
end