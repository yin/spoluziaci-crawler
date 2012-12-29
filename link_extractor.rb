require 'my_logger'

class DocumentLinkExtractor
  include MyLogger
  def initialize
  end

  def extract_files(html)
    doc = Nokogiri::HTML(html, nil, 'UTF-8')
    doc.encoding = 'utf-8'
    doc.xpath('//div[@class="dokument"]//table//tr').
    map { |cell| cell.at('td') }.
    select { |td| td != nil && td.at('a') != nil }.
    collect do |td|
      a = td.at('a')
      if a != nil
        name = a.text.strip
        href = a.attr('href')
        { :name => name,
          :href => href
        }
      end
    end
  end

  def extract_folders(html)
    Nokogiri::HTML(html).xpath('//table[@class="slozky"]//td/div/a').
    collect do |cell|
      name = cell.text.strip
      href = cell.attr('href')
      { :name => name,
        :href => href
      }
    end
  end
end
