class Hostdata
  LOCAL_FILE  = File.dirname(__FILE__) + '/data/@hostdata.yml'
  SOURCE_FILE = 'http://lmrwikiw1.which.co.uk/WikiWhich/Java_Development/EEnvironments'

  def get
    begin
      write parse_html
    rescue Exception=>e
      read
    end
  end

  private
  def hostdata_html
    hostdata_raw = open(SOURCE_FILE).read
    hostdata_html = Nokogiri::HTML(hostdata_raw)
    hostdata_html.encoding = 'utf-8'
    hostdata_html
  end

  def read
    YAML::load_file LOCAL_FILE
  end

  def write(details)
    File.open(LOCAL_FILE, "w") do |file|
      file.write details.to_yaml
    end
  end

  def parse_html
    rows = @hostdata_html.xpath('//tr')
    rows.collect do |row|
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
  end
end